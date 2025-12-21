# Redis Swarm Deployment Guide

**Date:** December 17, 2025
**Environment:** TeckGlobal 3-Node Docker Swarm

---

## Available Configurations

| File | Type | Modules | Use Case |
|------|------|---------|----------|
| `redis-stack-ha-stack.yml` | Sentinel + Redis Stack | ✅ Full | **RECOMMENDED** - HA with all modules |
| `redis-cluster-stack.yml` | Redis Cluster | ❌ None | Pure caching, data sharding |

---

## RECOMMENDED: Redis Stack HA (Sentinel)

### Why This Configuration?

- **Preserves Redis Stack modules** you're currently using:
  - RedisSearch (full-text search, vector search)
  - RedisJSON (JSON document storage)
  - RedisBloom (probabilistic data structures)
  - RedisTimeseries (time-series data)
  - RedisGears (serverless functions)

- **High Availability:**
  - 1 Master + 2 Read Replicas
  - 3 Sentinel instances for automatic failover
  - Quorum-based master election

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     TeckGlobal Docker Swarm                         │
├───────────────────┬───────────────────┬─────────────────────────────┤
│     oracle01      │     oracle02      │        tecklord01           │
│    10.0.206.10    │    10.0.206.20    │        10.48.1.15           │
├───────────────────┼───────────────────┼─────────────────────────────┤
│                   │                   │                             │
│  Redis Replica 1  │  Redis MASTER     │  Redis Replica 2            │
│  :6380 (768MB)    │  :6379 (1GB)      │  :6381 (384MB)              │
│                   │                   │                             │
│  Sentinel 1       │  Sentinel 2       │  Sentinel 3                 │
│  :26379           │  :26380           │  :26381                     │
│                   │                   │                             │
└───────────────────┴───────────────────┴─────────────────────────────┘
                              │
                     Overlay Network
                    (redis-ha-net)
                      MTU: 1388
```

### Memory Allocation

| Node | Role | RAM Limit | Reason |
|------|------|-----------|--------|
| oracle02 | Master | 1GB + 128MB sentinel | Most RAM, handles writes |
| oracle01 | Replica | 768MB + 128MB sentinel | Read offloading |
| tecklord01 | Replica | 384MB + 128MB sentinel | Limited RAM (4GB total) |

---

## Deployment Steps

### 1. Prepare All Nodes

Run on each Swarm node (oracle01, oracle02, tecklord01):

```bash
# Memory overcommit (prevents Redis background save failures)
sudo sysctl -w vm.overcommit_memory=1
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf

# Disable Transparent Huge Pages (reduces latency)
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

# Make THP setting persistent (add to /etc/rc.local or systemd)
```

### 2. Create Docker Secret

On the Swarm leader (oracle01):

```bash
# Generate secure password
openssl rand -base64 32

# Create secret (replace with your password)
echo "YourSecureRedisPassword2025!" | docker secret create redis_password -

# Verify
docker secret ls
```

### 3. Create Docker Config

```bash
# Navigate to stacks directory (or copy files to a manager node)
cd /path/to/stacks

# Create the sentinel config
docker config create sentinel_conf sentinel.conf

# Create the redis env helper
docker config create redis_env redis-env.sh

# Verify
docker config ls
```

### 4. Deploy the Stack

```bash
# Deploy Redis Stack HA
docker stack deploy -c redis-stack-ha-stack.yml redis-ha

# Monitor deployment (wait for all 6 services)
watch -n 2 'docker service ls | grep redis-ha'

# Expected output (after ~60 seconds):
# redis-ha_redis-master      replicated   1/1
# redis-ha_redis-replica-1   replicated   1/1
# redis-ha_redis-replica-2   replicated   1/1
# redis-ha_sentinel-1        replicated   1/1
# redis-ha_sentinel-2        replicated   1/1
# redis-ha_sentinel-3        replicated   1/1
```

### 5. Verify Cluster Health

```bash
# Check master info
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a YourSecureRedisPassword2025! --no-auth-warning INFO replication

# Expected: role:master, connected_slaves:2

# Check sentinel status
docker exec $(docker ps -q -f name=redis-ha_sentinel) \
  redis-cli -p 26379 SENTINEL masters

# Check Redis Stack modules
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a YourSecureRedisPassword2025! --no-auth-warning MODULE LIST
```

---

## Connecting Applications

### Connection Endpoints

| Purpose | Host | Port |
|---------|------|------|
| Master (writes) | redis-master | 6379 |
| Replica 1 (reads) | redis-replica-1 | 6379 |
| Replica 2 (reads) | redis-replica-2 | 6379 |
| Sentinel 1 | sentinel-1 | 26379 |
| Sentinel 2 | sentinel-2 | 26379 |
| Sentinel 3 | sentinel-3 | 26379 |

### External Access (Host Ports)

| Node | Redis Port | Sentinel Port |
|------|------------|---------------|
| oracle02 | 6379 | 26380 |
| oracle01 | 6380 | 26379 |
| tecklord01 | 6381 | 26381 |

### Node.js with ioredis (Sentinel-aware)

```javascript
const Redis = require('ioredis');

const redis = new Redis({
  sentinels: [
    { host: '10.0.206.10', port: 26379 },  // oracle01
    { host: '10.0.206.20', port: 26380 },  // oracle02
    { host: '10.48.1.15', port: 26381 }    // tecklord01
  ],
  name: 'redis-master',  // Sentinel master name
  password: 'YourSecureRedisPassword2025!',
  sentinelPassword: 'YourSecureRedisPassword2025!'
});

// Automatic failover - if master dies, ioredis reconnects to new master
redis.on('error', (err) => console.log('Redis error:', err));
redis.on('+switch-master', () => console.log('Master switched!'));
```

### Python with redis-py

```python
from redis.sentinel import Sentinel

sentinel = Sentinel([
    ('10.0.206.10', 26379),
    ('10.0.206.20', 26380),
    ('10.48.1.15', 26381)
], socket_timeout=0.5)

# Get master connection
master = sentinel.master_for(
    'redis-master',
    password='YourSecureRedisPassword2025!'
)

# Get replica for reads
replica = sentinel.slave_for(
    'redis-master',
    password='YourSecureRedisPassword2025!'
)
```

### Direct Connection (Non-Sentinel)

For services on the same overlay network:

```
redis://default:YourSecureRedisPassword2025!@redis-master:6379
```

---

## Using Redis Stack Features

### RedisSearch Example

```bash
# Create an index
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a YourPassword --no-auth-warning \
  FT.CREATE myindex ON HASH PREFIX 1 doc: SCHEMA title TEXT SORTABLE body TEXT

# Add a document
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a YourPassword --no-auth-warning \
  HSET doc:1 title "Hello World" body "This is a test document"

# Search
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a YourPassword --no-auth-warning \
  FT.SEARCH myindex "hello"
```

### RedisJSON Example

```bash
# Store JSON
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a YourPassword --no-auth-warning \
  JSON.SET user:1 $ '{"name":"John","age":30}'

# Query JSON
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a YourPassword --no-auth-warning \
  JSON.GET user:1 $.name
```

---

## Failover Testing

### Simulate Master Failure

```bash
# Stop the master container
docker service scale redis-ha_redis-master=0

# Watch sentinel logs (from any sentinel)
docker service logs -f redis-ha_sentinel-1

# Expected: +switch-master, new master elected

# Restore master (will rejoin as replica)
docker service scale redis-ha_redis-master=1
```

### Manual Failover

```bash
# Force failover via sentinel
docker exec $(docker ps -q -f name=redis-ha_sentinel) \
  redis-cli -p 26379 SENTINEL failover redis-master
```

---

## Monitoring

### Prometheus Metrics

Add to your Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: 'redis'
    static_configs:
      - targets:
        - '10.0.206.10:6380'  # oracle01 replica
        - '10.0.206.20:6379'  # oracle02 master
        - '10.48.1.15:6381'   # tecklord01 replica
```

### Key Metrics to Watch

```bash
# Memory usage
redis-cli INFO memory | grep used_memory_human

# Replication lag
redis-cli INFO replication | grep master_repl_offset

# Connected clients
redis-cli INFO clients | grep connected_clients

# Keyspace
redis-cli INFO keyspace
```

---

## Backup & Restore

### Backup (from Master)

```bash
# Trigger RDB snapshot
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a YourPassword --no-auth-warning BGSAVE

# Copy dump.rdb
docker cp $(docker ps -q -f name=redis-ha_redis-master):/data/dump.rdb ./redis-backup-$(date +%Y%m%d).rdb
```

### Backup AOF

```bash
# Rewrite AOF file
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a YourPassword --no-auth-warning BGREWRITEAOF

# Copy AOF
docker cp $(docker ps -q -f name=redis-ha_redis-master):/data/appendonlydir ./redis-aof-backup/
```

---

## Migration from Existing Redis

### Export Data from Current Instance

```bash
# From redis-orc2 (your current Redis Stack)
docker exec redis-orc2 redis-cli BGSAVE
docker cp redis-orc2:/data/dump.rdb ./redis-migration.rdb
```

### Import to New Cluster

```bash
# Stop the new master temporarily
docker service scale redis-ha_redis-master=0

# Copy dump.rdb to the volume
docker run --rm -v redis-ha_redis-master-data:/data -v $(pwd):/backup alpine \
  cp /backup/redis-migration.rdb /data/dump.rdb

# Start master (will load the data)
docker service scale redis-ha_redis-master=1
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check service logs
docker service logs redis-ha_redis-master --tail 100

# Common issues:
# - Secret not found: docker secret ls
# - Config not found: docker config ls
# - Network issues: docker network ls
```

### Replication Not Working

```bash
# Check master connectivity from replica
docker exec $(docker ps -q -f name=redis-ha_redis-replica-1) \
  redis-cli -h redis-master -a YourPassword ping

# Check replication info
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a YourPassword INFO replication
```

### Sentinel Can't Find Master

```bash
# Check sentinel logs
docker service logs redis-ha_sentinel-1

# Verify master is resolvable
docker exec $(docker ps -q -f name=redis-ha_sentinel-1) \
  ping -c 3 redis-master
```

### Sentinel Shows Master as Disconnected (Authentication Failed)

**Symptom:** Sentinel logs show `+sdown master` or master flags include `disconnected`. Redis master is running but Sentinel can't authenticate.

**Cause:** Environment variables like `${REDIS_PASSWORD}` in `REDIS_ARGS` are not substituted at runtime - they appear literally.

**Fix:** Construct `REDIS_ARGS` at container runtime, not in the environment block:

```yaml
# WRONG - password not substituted
environment:
  - REDIS_ARGS=--requirepass ${REDIS_PASSWORD} --masterauth ${REDIS_PASSWORD}
entrypoint: ["/bin/sh", "-c", "export REDIS_PASSWORD=$(cat /run/secrets/redis_password) && exec /entrypoint.sh"]

# CORRECT - password substituted at runtime
entrypoint: ["/bin/sh", "-c"]
command:
  - |
    REDIS_PASSWORD=$(cat /run/secrets/redis_password)
    export REDIS_ARGS="--requirepass $REDIS_PASSWORD --masterauth $REDIS_PASSWORD --maxmemory 1gb --maxmemory-policy allkeys-lru --appendonly yes"
    exec /entrypoint.sh
```

**Verify fix:**
```bash
# Check if password is working
docker exec $(docker ps -q -f name=redis-ha_redis-master) \
  redis-cli -a 'YourPassword' --no-auth-warning PING

# Check sentinel sees master correctly
docker exec $(docker ps -q -f name=redis-ha_sentinel-1) \
  redis-cli -p 26379 SENTINEL master redis-master | grep -A1 flags
# Should show: flags master (not: flags master,disconnected)
```

### Network MTU Issues (WireGuard VPN)

**Symptom:** Services stuck in "New" state, containers can't communicate across nodes.

**Cause:** Default MTU (1500) too large for WireGuard VPN tunnel.

**Fix:** Create overlay network with reduced MTU:
```bash
docker network create \
  --driver overlay \
  --attachable \
  --opt com.docker.network.driver.mtu=1388 \
  --subnet 10.52.0.0/24 \
  redis-ha-net
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `redis-stack-ha-stack.yml` | Main stack definition (RECOMMENDED) |
| `redis-cluster-stack.yml` | Alternative cluster config (no modules) |
| `sentinel.conf` | Sentinel configuration template |
| `redis-env.sh` | Environment helper script |
| `REDIS-DEPLOYMENT-GUIDE.md` | This documentation |

---

## Quick Reference

### Deploy
```bash
docker secret create redis_password - <<< "YourPassword"
docker config create sentinel_conf sentinel.conf
docker config create redis_env redis-env.sh
docker stack deploy -c redis-stack-ha-stack.yml redis-ha
```

### Remove
```bash
docker stack rm redis-ha
# Wait 10 seconds for cleanup
docker volume prune  # Optional: remove data
```

### Scale (not recommended for Redis)
```bash
# Redis HA should stay at 1 replica each
# Scaling won't help - use Redis Cluster instead for sharding
```

---

**Document Version:** 1.1
**Last Updated:** December 17, 2025
**Changes:** Added troubleshooting for password substitution and MTU issues
