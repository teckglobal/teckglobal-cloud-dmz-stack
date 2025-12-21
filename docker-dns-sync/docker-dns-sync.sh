#!/bin/bash
# Docker DNS Sync - Watches Docker containers and syncs hostnames to OpenWRT dnsmasq
# Uses UCI to manage DNS entries properly on OpenWRT

set -e

# Configuration
# Multiple routers supported - space-separated list
OPENWRT_HOSTS="${OPENWRT_HOSTS:-10.0.5.1 10.0.100.1}"
OPENWRT_USER="${OPENWRT_USER:-root}"
SSH_KEY="${SSH_KEY:-/root/.ssh/id_rsa}"
DNS_DOMAIN="${DNS_DOMAIN:-teck-global.lan}"
HOST_PREFIX="${HOST_PREFIX:-$(hostname | cut -d'.' -f1)}"
SYNC_INTERVAL="${SYNC_INTERVAL:-5}"
# Host IP for external access - must be set via environment or detected from hostname
if [[ -z "$HOST_IP" ]]; then
    case "$(hostname)" in
        *oracle01*) HOST_IP="10.0.206.10" ;;
        *oracle02*) HOST_IP="10.0.206.20" ;;
        *tecklord01*) HOST_IP="10.48.1.15" ;;
        *) HOST_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')" ;;
    esac
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

ssh_cmd() {
    local host="$1"
    shift
    ssh -q -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${OPENWRT_USER}@${host}" "$@"
}

# Get current docker containers with IPs
get_containers() {
    docker ps --format '{{.Names}}' | while read name; do
        # Get first valid IP (prefer bridge network)
        ip=$(docker inspect "$name" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{if $conf.IPAddress}}{{$conf.IPAddress}} {{end}}{{end}}' 2>/dev/null | awk '{print $1}')

        # Skip if no IP, empty, or invalid (host network mode)
        if [[ -z "$ip" || "$ip" == "null" || "$ip" == "invalid" || ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            continue
        fi

        # Clean name: remove only the long task ID (keep replica number), replace underscores and dots
        clean_name=$(echo "$name" | sed 's/\.[a-z0-9]\{20,\}$//' | sed 's/_/-/g' | sed 's/\./-/g' | tr '[:upper:]' '[:lower:]')
        echo "${clean_name}|${ip}"
    done
}

# Sync DNS entries to OpenWRT using UCI
sync_to_openwrt() {
    local containers="$1"
    local prefix="docker-${HOST_PREFIX}"

    log "Syncing DNS entries to ${OPENWRT_HOST}..."

    # Build UCI commands script
    local uci_script="#!/bin/sh
# Remove existing docker entries for this host
while uci -q delete dhcp.@domain[-1] 2>/dev/null; do
    name=\$(uci -q get dhcp.@domain[-1].name 2>/dev/null || echo '')
    if echo \"\$name\" | grep -q '^${prefix}-'; then
        uci delete dhcp.@domain[-1]
    else
        break
    fi
done

# Actually, let's do it properly - find and delete by name prefix
for i in \$(seq 100 -1 0); do
    name=\$(uci -q get dhcp.@domain[\$i].name 2>/dev/null || echo '')
    if echo \"\$name\" | grep -q '^${prefix}-'; then
        uci delete dhcp.@domain[\$i] 2>/dev/null || true
    fi
done
"

    # Add new entries
    while IFS='|' read -r name ip; do
        if [[ -n "$name" && -n "$ip" ]]; then
            local fqdn="${prefix}-${name}.${DNS_DOMAIN}"
            uci_script+="
uci add dhcp domain
uci set dhcp.@domain[-1].name='${fqdn}'
uci set dhcp.@domain[-1].ip='${ip}'
"
            log "  ${fqdn} -> ${ip}"
        fi
    done <<< "$containers"

    uci_script+="
uci commit dhcp
/etc/init.d/dnsmasq reload
"

    # Execute on OpenWRT
    if echo "$uci_script" | ssh_cmd "sh -s" 2>/dev/null; then
        log "Sync complete"
        return 0
    else
        log "ERROR: Sync failed"
        return 1
    fi
}

# Sync to all configured routers independently
sync_via_hosts() {
    local containers="$1"
    local hosts_content="# Docker containers from ${HOST_PREFIX} - $(date)"$'\n'
    hosts_content+="# Host IP: ${HOST_IP} (for external/nginx-ui access)"$'\n'

    while IFS='|' read -r name ip; do
        if [[ -n "$name" && -n "$ip" ]]; then
            # Add both IPs: container IP for internal, host IP for external
            hosts_content+="${ip} ${name}.${DNS_DOMAIN} ${name}"$'\n'
            hosts_content+="${HOST_IP} ${name}.${DNS_DOMAIN}"$'\n'
        fi
    done <<< "$containers"

    # Sync to each router independently (file per host to avoid conflicts)
    local remote_file="/etc/hosts.d/docker-${HOST_PREFIX}"
    for router in $OPENWRT_HOSTS; do
        if echo "$hosts_content" | ssh_cmd "$router" "cat > ${remote_file} && /etc/init.d/dnsmasq reload" 2>/dev/null; then
            log "Synced to ${router}:${remote_file}"
        else
            log "WARN: Failed to sync to ${router} (router may be unreachable)"
        fi
    done
}

# Watch Docker events and sync on changes
watch_and_sync() {
    log "Starting Docker DNS Sync"
    log "Routers: ${OPENWRT_HOSTS}"
    log "Domain: ${DNS_DOMAIN}, Host: ${HOST_PREFIX}, Host IP: ${HOST_IP}"

    # Initial sync
    log "Initial sync..."
    containers=$(get_containers)
    sync_via_hosts "$containers"

    # Watch for container events
    log "Watching for container events..."
    docker events --filter 'type=container' --filter 'event=start' --filter 'event=stop' --filter 'event=die' --format '{{.Action}} {{.Actor.Attributes.name}}' | while read event; do
        log "Event: $event"
        sleep 2  # Brief delay for container network to settle
        containers=$(get_containers)
        sync_via_hosts "$containers"
    done
}

# Periodic sync mode (alternative to event watching)
periodic_sync() {
    log "Starting periodic sync mode (every ${SYNC_INTERVAL}s)"
    log "Routers: ${OPENWRT_HOSTS}"
    log "Domain: ${DNS_DOMAIN}, Prefix: docker-${HOST_PREFIX}"

    local last_hash=""
    while true; do
        containers=$(get_containers)
        current_hash=$(echo "$containers" | md5sum | cut -d' ' -f1)

        if [[ "$current_hash" != "$last_hash" ]]; then
            log "Changes detected, syncing..."
            sync_via_hosts "$containers"
            last_hash="$current_hash"
        fi

        sleep "$SYNC_INTERVAL"
    done
}

# One-time sync
one_sync() {
    log "One-time sync..."
    containers=$(get_containers)
    echo "Containers found:"
    echo "$containers" | while IFS='|' read name ip; do
        echo "  $name -> $ip"
    done
    sync_via_hosts "$containers"
}

# Main
case "${1:-watch}" in
    watch)
        watch_and_sync
        ;;
    periodic)
        periodic_sync
        ;;
    sync)
        one_sync
        ;;
    list)
        get_containers
        ;;
    *)
        echo "Usage: $0 [watch|periodic|sync|list]"
        exit 1
        ;;
esac
