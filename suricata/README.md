# Suricata IDS Deployment Guide

> **Network Intrusion Detection System for the TeckGlobal Cloud DMZ Stack**

This directory contains a reference Docker deployment for Suricata IDS, integrated with Grafana Alloy for log collection and analysis.

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Rule Management](#rule-management)
- [Integration with Alloy](#integration-with-alloy)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)

---

## Overview

### What is Suricata?

Suricata is a high-performance Network Intrusion Detection System (NIDS), Intrusion Prevention System (IPS), and network security monitoring engine. It detects:

- **Malicious traffic patterns** - SQL injection, XSS, command injection
- **Known attack signatures** - Exploits, malware, botnets
- **Suspicious connections** - Port scans, brute force attempts
- **Protocol anomalies** - Malformed packets, unusual behavior

### Why Docker?

- **Isolation** - Runs in contained environment
- **Portability** - Consistent across different servers
- **Easy updates** - Pull new image, restart container
- **No system pollution** - No direct system-level installation

### Architecture in TeckGlobal Stack

```
┌──────────────────────────────────┐
│   Oracle02 (10.0.206.20)        │
│                                   │
│  ┌────────────────────────────┐  │
│  │   Docker: suricata-orc02   │  │
│  │   (Network packet capture) │  │
│  └───────────┬────────────────┘  │
│              │ Logs                │
│              ▼                     │
│  /var/log/suricata/eve.json       │
│              │                     │
│              ▼                     │
│  ┌────────────────────────────┐  │
│  │   Docker: alloy-orc02      │  │
│  │   (Log collection)         │  │
│  └───────────┬────────────────┘  │
└──────────────┼───────────────────┘
               │ Sends to
               ▼
┌──────────────────────────────────┐
│   Oracle01 (10.0.206.10)        │
│                                   │
│  ┌────────────────────────────┐  │
│  │   Docker: loki-orc01       │  │
│  │   (Log storage)            │  │
│  └────────────────────────────┘  │
│              │                     │
│              ▼                     │
│  ┌────────────────────────────┐  │
│  │   Grafana                  │  │
│  │   (Visualization & alerts) │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

---

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Root/sudo access (required for packet capture)
- Public-facing network interface
- Grafana Alloy configured (see [../grafana-alloy/README.md](../grafana-alloy/README.md))

### 1. Identify Your Network Interface

```bash
# List all network interfaces
ip addr show

# Common interface names:
# - eth0, eth1 (traditional naming)
# - ens3, ens5 (predictable naming on cloud VMs)
# - enp0s3 (predictable naming on physical servers)
```

Look for the interface with your public IP address.

### 2. Update docker-compose.yml

Edit `docker-compose.yml` and update the interface name:

```yaml
environment:
  - SURICATA_OPTIONS=-i eth0  # Change eth0 to YOUR interface
```

### 3. Deploy Suricata

```bash
# Navigate to suricata directory
cd /opt/teckglobal-cloud-dmz-stack/suricata

# Deploy
docker-compose up -d

# Verify
docker logs -f suricata-orc02
```

### 4. Verify Logs are Generating

```bash
# Watch eve.json log file
tail -f /var/log/suricata/eve.json

# You should see JSON entries like:
# {"timestamp":"2025-01-15T10:30:45.123456+0000","flow_id":123456,"event_type":"flow",...}
```

### 5. Verify Alloy is Collecting Logs

```bash
# Check Alloy logs
docker logs alloy-orc02 | grep suricata

# Query Loki for Suricata logs
curl -G -s "http://10.0.206.10:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="suricata"}' \
  --data-urlencode 'limit=5' | jq
```

---

## Configuration

### Basic Configuration

The default configuration works well for most use cases. If you need custom configuration:

**1. Extract default config:**

```bash
mkdir -p config
docker run --rm jasonish/suricata:latest cat /etc/suricata/suricata.yaml > config/suricata.yaml
```

**2. Edit configuration:**

```bash
nano config/suricata.yaml
```

**3. Uncomment volume mount in docker-compose.yml:**

```yaml
volumes:
  - ./config/suricata.yaml:/etc/suricata/suricata.yaml:ro
```

**4. Restart Suricata:**

```bash
docker-compose restart
```

### Common Configuration Changes

**Home Networks (for internal IP ranges):**

Edit `suricata.yaml`:

```yaml
vars:
  address-groups:
    HOME_NET: "[10.0.0.0/8,192.168.0.0/16,172.16.0.0/12]"
    EXTERNAL_NET: "!$HOME_NET"
```

**Performance Tuning:**

```yaml
# Increase worker threads (number of CPU cores)
threading:
  set-cpu-affinity: no
  cpu-affinity:
    - management-cpu-set:
        cpu: [ 0 ]
    - receive-cpu-set:
        cpu: [ 1,2,3,4 ]
```

**Logging Options:**

```yaml
outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert
        - http
        - dns
        - tls
        - flow
        # Disable noisy event types:
        # - stats
        # - netflow
```

---

## Rule Management

### Default Rules

Suricata ships with Emerging Threats Open ruleset (free). Rules are automatically updated.

### Viewing Active Rules

```bash
# List all enabled rules
docker exec suricata-orc02 ls -lh /var/lib/suricata/rules/

# Count active rules
docker exec suricata-orc02 cat /var/lib/suricata/rules/*.rules | grep -c "^alert"
```

### Updating Rules

**Automatic (recommended):**

Rules update automatically when the container restarts:

```bash
docker restart suricata-orc02
```

**Manual update:**

```bash
# Update rules inside container
docker exec suricata-orc02 suricata-update

# Reload rules without restart
docker exec suricata-orc02 kill -USR2 1
```

### Custom Rules

**1. Create custom rules directory:**

```bash
mkdir -p rules
```

**2. Add custom rules:**

```bash
# Example: Alert on SSH brute force attempts
cat > rules/custom.rules <<EOF
alert tcp any any -> $HOME_NET 22 (msg:"Possible SSH brute force"; \
  flow:to_server; flags:S; \
  threshold: type both, track by_src, count 10, seconds 60; \
  classtype:attempted-recon; sid:1000001; rev:1;)
EOF
```

**3. Uncomment rules volume in docker-compose.yml:**

```yaml
volumes:
  - ./rules:/etc/suricata/rules:ro
```

**4. Restart Suricata:**

```bash
docker-compose restart
```

---

## Integration with Alloy

Alloy automatically collects Suricata logs from `/var/log/suricata/eve.json`.

### Alloy Configuration

Already configured in [grafana-alloy/configs/oracle02-alloy.alloy](../grafana-alloy/configs/oracle02-alloy.alloy):

```hcl
loki.source.file "suricata" {
  targets = [
    {
      __path__ = "/var/log/suricata/eve.json",
      job      = "suricata",
      host     = "oracle02",
    },
  ]
  forward_to = [loki.process.suricata.receiver]
}

loki.process "suricata" {
  stage.json {
    expressions = {
      event_type = "event_type",
      proto      = "proto",
      src_ip     = "src_ip",
      dest_ip    = "dest_ip",
      dest_port  = "dest_port",
    }
  }

  // GeoIP enrichment
  stage.geoip {
    db     = "/geoip/GeoLite2-City.mmdb"
    source = "src_ip"
  }

  // Low-cardinality labels only
  stage.labels {
    values = {
      event_type = "event_type",
      proto      = "proto",
    }
  }

  stage.static_labels {
    values = {
      job  = "suricata",
      host = "oracle02",
    }
  }

  forward_to = [loki.write.loki_central.receiver]
}
```

### Querying Suricata Logs

**In Grafana Explore:**

```logql
# All Suricata alerts
{job="suricata", event_type="alert"}

# Alerts from specific country
{job="suricata", event_type="alert"} | json | geoip_country_name="China"

# SQL injection attempts
{job="suricata", event_type="alert"} | json | signature=~".*SQL.*"

# Top attacking IPs
sum by (src_ip) (count_over_time({job="suricata", event_type="alert"}[1h]))

# HTTP traffic
{job="suricata", event_type="http"}

# DNS queries
{job="suricata", event_type="dns"}
```

---

## Performance Tuning

### Resource Allocation

Adjust CPU and memory limits in docker-compose.yml:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'      # Use 2 CPU cores
      memory: 2G       # Limit memory to 2GB
    reservations:
      cpus: '1.0'      # Reserve 1 CPU core
      memory: 1G       # Reserve 1GB memory
```

### High-Traffic Environments

For servers handling >1 Gbps traffic:

**1. Enable AF_PACKET:**

```yaml
environment:
  - SURICATA_OPTIONS=-i eth0 --af-packet
```

**2. Increase worker threads:**

Edit `config/suricata.yaml`:

```yaml
af-packet:
  - interface: eth0
    threads: 4          # Match CPU core count
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
```

**3. Increase ring buffer:**

```yaml
af-packet:
  - interface: eth0
    ring-size: 4096     # Increase from default 2048
```

### Log Rotation

Suricata's eve.json can grow large. Implement log rotation:

```bash
# Create logrotate config
sudo cat > /etc/logrotate.d/suricata <<EOF
/var/log/suricata/eve.json {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        docker exec suricata-orc02 kill -HUP 1
    endscript
}
EOF
```

---

## Troubleshooting

### No Logs Generated

**Problem:** `/var/log/suricata/eve.json` is empty

**Solutions:**
```bash
# 1. Verify Suricata is running
docker ps | grep suricata

# 2. Check Suricata logs for errors
docker logs suricata-orc02

# 3. Verify interface name is correct
ip addr show
# Update docker-compose.yml with correct interface

# 4. Check permissions on log directory
ls -ld /var/log/suricata
# Should be writable by Docker

# 5. Restart Suricata
docker-compose restart
```

### High CPU Usage

**Problem:** Suricata consuming excessive CPU

**Solutions:**
1. **Reduce rule count** - Disable unnecessary rule categories
2. **Limit CPU** - Add resource limits in docker-compose.yml
3. **Optimize configuration** - Tune threading and buffer sizes
4. **Filter traffic** - Use BPF filter to ignore internal traffic:

```yaml
environment:
  - SURICATA_OPTIONS=-i eth0 --af-packet=bpf-filter="not host 10.0.206.10"
```

### Packet Drops

**Problem:** Suricata dropping packets (visible in stats.log)

**Solutions:**
1. **Increase worker threads** - Match CPU core count
2. **Increase ring buffer size** - See performance tuning above
3. **Enable AF_PACKET** - Better performance than pcap
4. **Add more resources** - Increase CPU/memory limits

### Permission Denied Errors

**Problem:** Suricata can't capture packets

**Solutions:**
```bash
# Verify capabilities in docker-compose.yml
cap_add:
  - NET_ADMIN
  - SYS_NICE
  - NET_RAW

# Restart with updated capabilities
docker-compose down
docker-compose up -d
```

---

## Additional Resources

- [Suricata Official Documentation](https://suricata.readthedocs.io/)
- [jasonish/docker-suricata GitHub](https://github.com/jasonish/docker-suricata)
- [Suricata Rule Writing Guide](https://suricata.readthedocs.io/en/latest/rules/)
- [Emerging Threats Rules](https://rules.emergingthreats.net/)
- [Grafana Alloy Integration](../grafana-alloy/README.md)

---

**Built with ❤️ by TeckGlobal** | [GitHub](https://github.com/teckglobal/teckglobal-cloud-dmz-stack)
