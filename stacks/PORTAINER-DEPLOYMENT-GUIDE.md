# Portainer Enterprise Deployment Guide

## Overview
Portainer Business Edition 2.37.0 deployed on Docker Swarm with agent clustering.

## Network Setup

Create dedicated overlay network first:
```bash
docker network create \
  --attachable \
  --driver overlay \
  --subnet 10.0.220.0/24 \
  --gateway 10.0.220.1 \
  --opt com.docker.network.driver.mtu=1368 \
  portainer_network
```

## Service Deployments

### Portainer Agent (Global Service)

```bash
docker service create \
  --name portainer_agent \
  --network portainer_network \
  --mode global \
  -p 9001:9001/tcp \
  -e AGENT_CLUSTER_ADDR=tasks.portainer_agent \
  --constraint 'node.platform.os==linux' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/var/lib/docker/volumes,dst=/var/lib/docker/volumes \
  --mount type=bind,src=/,dst=/host \
  --limit-memory 128M \
  --reserve-memory 64M \
  --label com.docker.stack.namespace=portainer \
  --label com.docker.stack.image=portainer/agent:2.37.0 \
  portainer/agent:2.37.0
```

### Portainer Server (Replicated Service)

```bash
docker service create \
  --name portainer \
  --network portainer_network \
  --replicas 1 \
  --constraint 'node.role == manager' \
  --constraint 'node.hostname == oracle01.teck-global.com' \
  -p 9443:9443 \
  -p 9000:9000 \
  -p 8000:8000 \
  -e TZ=America/Chicago \
  --mount type=volume,src=portainer_data,dst=/data \
  --limit-memory 512M \
  --reserve-memory 256M \
  --label com.docker.stack.namespace=portainer \
  --label com.docker.stack.image=portainer/portainer-ee:2.37.0 \
  portainer/portainer-ee:2.37.0 \
  -H tcp://tasks.portainer_agent:9001 --tlsskipverify
```

## Critical Configuration Notes

### Network Connectivity
- **IMPORTANT**: Both `portainer_agent` and `portainer` services MUST be on the same network (`portainer_network`)
- If portainer server cannot resolve `tasks.portainer_agent:9001`, add the network:
  ```bash
  docker service update portainer --network-add portainer_network
  ```

### DNS Resolution
- Service name `portainer_agent` creates DNS entry `tasks.portainer_agent`
- Portainer server uses `-H tcp://tasks.portainer_agent:9001` to connect to agents
- DNS resolution only works within the same overlay network

### Agent Clustering
- `AGENT_CLUSTER_ADDR=tasks.portainer_agent` enables Serf-based agent clustering
- Agents discover each other automatically via this DNS entry
- All 3 nodes join the cluster and communicate on overlay network IPs

### Labels
- **Service labels** (`--label`): Identify services in `docker service ls` output
- **Container labels**: Show when listing containers with `docker ps`
- Use `com.docker.stack.namespace=portainer` to group services logically

### Endpoint Configuration
- The `-H` flag sets the DEFAULT endpoint for NEW environments only
- Existing endpoints stored in `portainer_data` volume override this setting
- If migrating, update endpoint URL in Portainer UI: Environments → Edit → URL

## Resource Limits

| Service | Memory Limit | Memory Reserve |
|---------|--------------|----------------|
| portainer_agent | 128M | 64M |
| portainer | 512M | 256M |

## Ports

| Port | Service | Purpose |
|------|---------|---------|
| 9443 | portainer | HTTPS UI |
| 9000 | portainer | HTTP UI |
| 8000 | portainer | Edge Agent tunnel |
| 9001 | portainer_agent | Agent API |

## Volumes

- `portainer_data` - Persistent data (database, configs, certificates)

## Verification Commands

```bash
# Check services
docker service ls | grep portainer

# Check agent clustering (look for Serf EventMemberJoin)
docker service logs portainer_agent --tail 20

# Check portainer connectivity
docker service logs portainer --tail 20

# Verify network attachment
docker service inspect portainer --format '{{json .Spec.TaskTemplate.Networks}}'
docker service inspect portainer_agent --format '{{json .Spec.TaskTemplate.Networks}}'
```

## Troubleshooting

### "no such host" error for tasks.portainer_agent
- Ensure both services are on the same overlay network
- Check: `docker service update portainer --network-add portainer_network`

### Connection refused to host IP (e.g., 10.0.206.10:9001)
- Persisted endpoint in portainer_data using old IP
- Fix in UI: Environments → Edit endpoint → Change URL to `tasks.portainer_agent:9001`

### Services stuck in "New" state
- Check if overlay network is properly created
- Try using an existing working overlay network
- Verify swarm health: `docker node ls`

---
**Version**: 2.37.0
**Last Updated**: December 2025
**Network**: portainer_network (10.0.220.0/24)

---

# MTU Configuration - Test Results (December 2025)

## MTU Chain Summary

```
Internet Gateway (1428 MTU)
  ↓ -60 bytes WireGuard overhead
WireGuard Tunnels (1368 MTU)
  ↓
VM Interfaces (1368 MTU)
  ↓
Docker Networks (1368 MTU)
  ↓ -50 bytes VXLAN overlay overhead
Containers (1318 MTU)
```

## Test Results

### From Mac Mini (WiFi at 1368)

| Destination | Payload | MTU | Result |
|-------------|---------|-----|--------|
| 8.8.8.8 (internet) | 1472 | 1500 | ❌ frag needed (MTU 1428) |
| 8.8.8.8 (internet) | 1400 | 1428 | ✅ Works |
| 10.0.206.10 (tunnel) | 1400 | 1428 | ❌ frag needed (MTU 1368) |
| 10.0.206.10 (tunnel) | 1340 | 1368 | ✅ Works |

### From VM 10.48.1.15 (enp2s0 at 1368)

| Destination | Payload | MTU | Result |
|-------------|---------|-----|--------|
| 8.8.8.8 | 1340 | 1368 | ✅ 0% loss |
| 10.0.206.10 | 1340 | 1368 | ✅ 0% loss |
| 10.0.206.20 | 1340 | 1368 | ✅ 0% loss |

## VMware Fusion Bridged Networking

- Mac WiFi MTU: 1368
- VM (10.48.1.15) interface: 1368
- **Result**: No additional overhead from VMware Fusion bridge
- Both devices share same MAC address, router sees 2 IPs

## Recommended MTU Settings

| Device/Path | MTU | Notes |
|-------------|-----|-------|
| Internet only (no tunnel) | 1400 | Avoids fragmentation on 1428 gateway |
| WireGuard tunnel devices | 1368 | Required for tunnel traversal |
| Docker overlay networks | 1368 | Set via `--opt com.docker.network.driver.mtu=1368` |
| Containers | 1318 | Automatic (1368 - 50 VXLAN overhead) |

## Labels Note

- **Service labels** (`docker service update --label-add`): Identify services in `docker service ls`
- **Container labels**: Show when listing containers with `docker ps`
- Both types use `com.docker.stack.namespace` for grouping
