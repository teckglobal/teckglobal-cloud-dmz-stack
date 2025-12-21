# Redis Cluster Swarm Deployment Guide

**Date:** December 17, 2025
**Environment:** TeckGlobal 3-Node Docker Swarm

---

## Important Consideration

**Redis Cluster vs Redis Stack:**

The Bitnami `redis-cluster` image does **NOT** include Redis Stack modules (RedisSearch, RedisJSON, RedisBloom, etc.) that you're currently using.

| Feature | Current Setup (Redis Stack) | Redis Cluster |
|---------|----------------------------|---------------|
| RedisSearch | ✅ | ❌ |
| RedisJSON | ✅ | ❌ |
| RedisBloom | ✅ | ❌ |
| RedisTimeseries | ✅ | ❌ |
| Data Sharding | ❌ | ✅ |
| Auto-failover | ❌ | ✅ |

**If you need Redis Stack modules**, consider:
1. Redis Sentinel + Redis Stack (HA without sharding)
2. Separate Redis Stack instances for module-dependent apps
3. Redis Enterprise (commercial, supports both)

---

## Deployment Steps

### 1. Prerequisites (Run on Leader Node - oracle01)

```bash
# Set memory overcommit on ALL nodes
ssh oracle01 "sudo sysctl -w vm.overcommit_memory=1 && echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf"
ssh oracle02 "sudo sysctl -w vm.overcommit_memory=1 && echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf"
ssh debian-vm "sudo sysctl -w vm.overcommit_memory=1 && echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf"

# Disable THP (Transparent Huge Pages) on ALL nodes
ssh oracle01 "echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled"
ssh oracle02 "echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled"
ssh debian-vm "echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled"
```

### 2. Create Docker Secret for Password

```bash
# Generate a secure password and create secret
echo "YourSecureRedisPassword2025!" | docker secret create redis_password -

# Verify secret exists
docker secret ls
```

### 3. Deploy the Stack

```bash
# Deploy from the stacks directory
docker stack deploy -c redis-cluster-stack.yml redis-cluster

# Monitor deployment
watch docker service ls
```

### 4. Verify Cluster Status

```bash
# Wait for all services to be running (1-2 minutes)
docker service ls | grep redis-cluster

# Check cluster info from any node
docker exec $(docker ps -q -f name=redis-cluster_redis-node) \
  redis-cli -a "YourSecureRedisPassword2025!" cluster info

# Check cluster nodes
docker exec $(docker ps -q -f name=redis-cluster_redis-node) \
  redis-cli -a "YourSecureRedisPassword2025!" cluster nodes
```

---

## Key Changes from Your Template

### 1. Version Upgrade
```yaml
# Before
image: docker.io/bitnami/redis-cluster:6.2

# After
image: docker.io/bitnami/redis-cluster:7.4
```
Redis 7.4 includes performance improvements and better cluster stability.

### 2. Swarm Deploy Section
```yaml
deploy:
  mode: replicated
  replicas: 1
  placement:
    constraints:
      - node.hostname == oracle01.teck-global.com  # Pin to specific node
  resources:
    limits:
      memory: 1G      # Prevent OOM kills
    reservations:
      memory: 256M    # Guaranteed minimum
  restart_policy:
    condition: on-failure
    delay: 5s
    max_attempts: 3
```

### 3. Secrets Instead of Environment Variables
```yaml
# Before (insecure)
environment:
  - "REDIS_PASSWORD=${REDIS_PASSWD}"

# After (secure)
environment:
  - REDIS_PASSWORD_FILE=/run/secrets/redis_password
secrets:
  - redis_password
```

### 4. Overlay Network with MTU
```yaml
networks:
  redis-cluster-net:
    driver: overlay
    attachable: true
    driver_opts:
      com.docker.network.driver.mtu: "1388"  # Tuned for WireGuard VPN
```

### 5. Health Checks
```yaml
healthcheck:
  test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "$$(cat /run/secrets/redis_password)", "ping"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

### 6. Cluster Announce Settings
```yaml
environment:
  - REDIS_CLUSTER_ANNOUNCE_IP=redis-node-0    # Use service name
  - REDIS_CLUSTER_ANNOUNCE_PORT=6379
  - REDIS_CLUSTER_ANNOUNCE_BUS_PORT=16379
  - REDIS_CLUSTER_DYNAMIC_IPS=no              # Required for Swarm
```

---

## Memory Allocation

Based on your server resources:

| Node | Total RAM | Other Services | Redis Limit |
|------|-----------|----------------|-------------|
| oracle01 | 10GB | Grafana, Mimir, Loki, etc. | 1GB |
| oracle02 | 12GB | 6x MariaDB, Nginx, Suricata | 1GB |
| tecklord01 | 4GB | Development, UrBackup | 512MB |

---

## Connecting Applications

### Connection String
```
redis://default:YourPassword@redis-node-0:6379,redis-node-1:6379,redis-node-2:6379
```

### Node.js Example
```javascript
const Redis = require('ioredis');

const cluster = new Redis.Cluster([
  { host: 'redis-node-0', port: 6379 },
  { host: 'redis-node-1', port: 6379 },
  { host: 'redis-node-2', port: 6379 }
], {
  redisOptions: {
    password: 'YourSecureRedisPassword2025!'
  },
  scaleReads: 'slave'  // Read from replicas if available
});
```

### Python Example
```python
from redis.cluster import RedisCluster

rc = RedisCluster(
    host='redis-node-0',
    port=6379,
    password='YourSecureRedisPassword2025!'
)
```

---

## Scaling Options

### Option A: 3 Masters, 0 Replicas (Current)
- Each node has 1 master
- Data sharded across 3 nodes
- If 1 node fails, ~33% of keys unavailable

### Option B: 3 Masters, 3 Replicas (High Availability)
Requires 6 Redis instances. Modify stack:
```yaml
environment:
  - REDIS_CLUSTER_REPLICAS=1
  - REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5
```

---

## Monitoring

### Prometheus Metrics
Add to each service:
```yaml
environment:
  - REDIS_EXPORTER_ENABLED=true
```

### Manual Health Check
```bash
# Check cluster health
docker exec redis-cluster_redis-node-0.1.xxx redis-cli -a PASSWORD cluster info | grep cluster_state

# Should return: cluster_state:ok
```

---

## Troubleshooting

### Cluster Won't Form
```bash
# Check logs on creator node (redis-node-2)
docker service logs redis-cluster_redis-node-2

# Common issues:
# - Nodes can't reach each other (network/MTU issue)
# - Password mismatch
# - Port 16379 blocked (cluster bus)
```

### Node Shows as "fail"
```bash
# Remove failed node and let cluster heal
redis-cli -a PASSWORD cluster forget <node-id>
```

### Reset and Recreate
```bash
# Remove stack
docker stack rm redis-cluster

# Remove volumes (CAUTION: deletes data!)
docker volume rm redis-cluster_redis-cluster_data-0
docker volume rm redis-cluster_redis-cluster_data-1
docker volume rm redis-cluster_redis-cluster_data-2

# Redeploy
docker stack deploy -c redis-cluster-stack.yml redis-cluster
```

---

## Migration from Standalone Redis

If migrating data from existing Redis Stack instances:

1. **Export data** from current Redis:
   ```bash
   docker exec redis-orc2 redis-cli BGSAVE
   docker cp redis-orc2:/data/dump.rdb ./dump.rdb
   ```

2. **Note:** RDB files from Redis Stack with modules may not import cleanly to standard Redis Cluster

3. **Recommended approach:** Application-level migration or fresh start

---

## Files

- `redis-cluster-stack.yml` - Swarm stack definition
- `REDIS-CLUSTER-DEPLOYMENT.md` - This guide

---

**Document Version:** 1.0
**Last Updated:** December 17, 2025
