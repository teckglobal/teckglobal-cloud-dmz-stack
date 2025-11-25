# Grafana Alloy Deployment Guide

> **Unified Observability Agent** - Collect logs AND metrics with a single agent

This directory contains production-ready Grafana Alloy configurations for the TeckGlobal Cloud DMZ Stack.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Why Alloy](#why-alloy-over-promtail)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Deployment Steps](#deployment-steps)
- [Cardinality Optimization](#cardinality-optimization)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## 🌟 Overview

This setup migrates from **Promtail** (deprecated) to **Grafana Alloy** (actively developed) with critical cardinality optimizations to prevent Loki's "maximum stream limit exceeded" errors.

### What's Included

| File | Purpose |
|------|---------|
| `configs/oracle01-alloy.alloy` | Oracle01 unified config (logs + metrics) |
| `configs/oracle02-alloy.alloy` | Oracle02 config (sends to Oracle01) |
| `docker-compose-oracle01.yml` | Oracle01 deployment |
| `docker-compose-oracle02.yml` | Oracle02 deployment |

### Servers

- **Oracle01** (10.0.206.10) - Monitoring Hub
  - Runs: Alloy, Loki, Mimir, Grafana
  - Receives: Logs from Oracle02, syslog from routers

- **Oracle02** (10.0.206.20) - Application Server
  - Runs: Alloy (collector only)
  - Sends: Logs + metrics to Oracle01

---

## 🚀 Why Alloy Over Promtail?

| Feature | Promtail | Alloy |
|---------|----------|-------|
| **Status** | Deprecated | Actively Developed |
| **Capabilities** | Logs only | Logs + Metrics + Traces |
| **Performance** | Good | Excellent |
| **Configuration** | YAML | HCL (more flexible) |
| **Cardinality Control** | Limited | Built-in optimizations |
| **Community** | Stable | Growing fast |

**Key Benefit:** Replace multiple agents (Promtail + Prometheus Agent) with one unified Alloy agent.

---

## 🏗️ Architecture

### Data Flow (After Migration)

```
┌────────────────────┐
│   Oracle02         │
│                    │
│  • Nginx logs      │──┐
│  • Suricata logs   │  │
│  • System logs     │  │ Logs
│  • Syslog          │  │
│                    │  │
│  ┌──────────────┐  │  │
│  │ Alloy Agent  │──┘  │
│  └──────────────┘     │
└────────────────────┘  │
                        │
┌────────────────────┐  │
│   OpenWrt Routers  │  │
│                    │  │
│  • Firewall logs   │──┤ Syslog
│  • System logs     │  │ UDP
└────────────────────┘  │
                        │
                        ▼
┌──────────────────────────────────┐
│   Oracle01 (Monitoring Hub)      │
│                                   │
│  ┌────────────────────────────┐  │
│  │      Alloy Agent           │  │
│  │  (Collects + Receives)     │  │
│  └───────────┬────────────────┘  │
│              │                    │
│         ┌────┴────┐               │
│         │         │               │
│    ┌────▼───┐ ┌──▼────┐          │
│    │  Loki  │ │ Mimir │          │
│    │ (Logs) │ │(Metrics)         │
│    └────┬───┘ └──┬────┘          │
│         │         │               │
│         └────┬────┘               │
│              │                    │
│         ┌────▼───────┐            │
│         │  Grafana   │            │
│         └────────────┘            │
└──────────────────────────────────┘
```

### Stream Count Reduction

**Before (Promtail with high cardinality):**
```
Suricata logs: 10,000+ streams ❌
Nginx logs:    500+ streams ❌
Total:         10,500+ streams → 429 ERRORS!
```

**After (Alloy with optimized cardinality):**
```
Suricata logs: ~20 streams ✅
Nginx logs:    ~15 streams ✅
Total:         ~35 streams → NO ERRORS!
```

**99.7% reduction in streams!**

---

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Oracle01: Loki and Mimir containers running
- Ports available:
  - Oracle01: 12345, 1515/udp, 1516/udp
  - Oracle02: 12346

### 1. Clone Repository

```bash
git clone https://github.com/teckglobal/teckglobal-cloud-dmz-stack
cd teckglobal-cloud-dmz-stack/grafana-alloy
```

### 2. Deploy Oracle01 (Monitoring Hub)

```bash
# Stop existing Promtail (if running)
docker stop promtail
docker rm promtail

# Deploy Alloy
docker-compose -f docker-compose-oracle01.yml up -d

# Verify
docker logs -f alloy
```

### 3. Deploy Oracle02 (Application Server)

```bash
# Stop existing Promtail containers
docker stop promtail-orc2 promtail-orc2-suricata
docker rm promtail-orc2 promtail-orc2-suricata

# Deploy Alloy
docker-compose -f docker-compose-oracle02.yml up -d

# Verify
docker logs -f alloy-oracle02
```

---

## 📖 Deployment Steps

### Oracle01 Deployment

**Step 1: Prepare Configuration**

```bash
# Navigate to grafana-alloy directory
cd /opt/teckglobal-cloud-dmz-stack/grafana-alloy

# Review and customize oracle01-alloy.alloy if needed
nano configs/oracle01-alloy.alloy
```

**Step 2: Stop Existing Promtail**

```bash
# Check if Promtail is running
docker ps | grep promtail

# Stop and remove
docker stop promtail
docker rm promtail

# Optional: Remove Promtail volume (after backing up)
# docker volume rm promtail-data
```

**Step 3: Deploy Alloy**

```bash
# Deploy
docker-compose -f docker-compose-oracle01.yml up -d

# Check status
docker ps | grep alloy
```

**Step 4: Verify Logs are Flowing**

```bash
# Check Alloy logs
docker logs -f alloy

# You should see:
# - "component started" messages
# - Log ingestion activity
# - No error messages

# Check Alloy metrics endpoint
curl http://localhost:12345/metrics | grep loki_

# Access Alloy UI
# http://10.0.206.10:12345
```

**Step 5: Verify in Loki**

```bash
# Query Loki for recent logs
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="syslog"}' \
  --data-urlencode 'limit=10' | jq

# Check stream count (should be low!)
curl -s "http://localhost:3100/loki/api/v1/streams" | jq '. | length'
```

---

### Oracle02 Deployment

**Step 1: Prepare Configuration**

```bash
# Navigate to grafana-alloy directory
cd /opt/teckglobal-cloud-dmz-stack/grafana-alloy

# Review oracle02-alloy.alloy
nano configs/oracle02-alloy.alloy

# Verify paths:
# - /var/www/html/*/logs/*.log (nginx logs)
# - /var/log/suricata/eve.json (Suricata IDS)
```

**Step 2: Stop Existing Promtail Containers**

```bash
# Check running Promtail containers
docker ps | grep promtail

# Stop both Promtail containers
docker stop promtail-orc2 promtail-orc2-suricata
docker rm promtail-orc2 promtail-orc2-suricata
```

**Step 3: Deploy Alloy**

```bash
# Deploy
docker-compose -f docker-compose-oracle02.yml up -d

# Check status
docker ps | grep alloy
```

**Step 4: Verify Connectivity to Oracle01**

```bash
# Check if Oracle01's Loki is reachable
curl -s http://10.0.206.10:3100/ready

# Check if Oracle01's Mimir is reachable
curl -s http://10.0.206.10:9009/ready
```

**Step 5: Verify Logs are Being Sent**

```bash
# Check Alloy logs
docker logs -f alloy-oracle02

# You should see:
# - Nginx log collection activity
# - Suricata log parsing
# - No connection errors to Oracle01

# Check metrics endpoint
curl http://localhost:12346/metrics | grep loki_

# Access Alloy UI
# http://10.0.206.20:12346
```

**Step 6: Verify in Loki (from Oracle01)**

```bash
# SSH to Oracle01
ssh tecklord-admin@10.0.206.10

# Query nginx logs from Oracle02
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="nginx_access", host="oracle02"}' \
  --data-urlencode 'limit=10' | jq

# Query Suricata logs from Oracle02
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="suricata", host="oracle02"}' \
  --data-urlencode 'limit=10' | jq

# Check total stream count
curl -s "http://localhost:3100/loki/api/v1/streams" | jq '. | length'
# Should be under 100 streams!
```

---

## 🎯 Cardinality Optimization

### The Problem

Loki uses labels to create **streams**. Each unique combination of labels creates a new stream. Default limit: **10,000 streams per tenant**.

**BAD Example (High Cardinality):**
```
{
  job="suricata",
  src_ip="1.2.3.4",              ← 1000s of unique IPs
  dest_port="443",               ← 100s of ports
  geoip_city="London",           ← 1000s of cities
  geoip_lat="51.5081",           ← Infinite precision
  geoip_long="-0.1278",          ← Infinite precision
  signature="SQL Injection"      ← 100s of signatures
}
```
**Result:** 10,000+ streams = "maximum stream limit exceeded" errors!

### The Solution

**GOOD Example (Low Cardinality):**
```
{
  job="suricata",           ← 1 value
  host="oracle02",          ← 1 value
  event_type="alert",       ← ~10 values
  proto="TCP"               ← ~5 values
}
```
**Result:** ~50 streams = fast, efficient, no errors!

### How to Query High-Cardinality Fields

Use **LogQL** to query fields AFTER ingestion:

```logql
# Query by source IP
{job="suricata"} | json | src_ip="1.2.3.4"

# Query by GeoIP city
{job="suricata"} | json | geoip_city_name="London"

# Query by signature
{job="suricata", event_type="alert"} | json | signature=~".*SQL.*"

# Query nginx by status code
{job="nginx_access"} | json | status="404"

# Query nginx by IP
{job="nginx_access"} | json | remote_addr="1.2.3.4"
```

### Label Best Practices

**✅ Good Labels (Low Cardinality):**
- `job` - Service name (e.g., "nginx_access", "suricata")
- `host` - Server name (e.g., "oracle01", "oracle02")
- `website` - Website name (e.g., "theailotto.com") - only ~10 sites
- `event_type` - Event category (e.g., "alert", "flow", "tls")
- `proto` - Protocol (e.g., "TCP", "UDP", "ICMP")

**❌ Bad Labels (High Cardinality):**
- `src_ip`, `dest_ip` - Thousands of IPs
- `src_port`, `dest_port` - Thousands of ports
- `geoip_city_name` - Thousands of cities
- `geoip_location_*` - Infinite precision coordinates
- `signature`, `signature_id` - Hundreds of values
- `request_uri` - Infinite URLs
- `http_user_agent` - Thousands of agents
- `filename` - One per log file

---

## 🌍 GeoIP Integration

### Overview

GeoIP processing enriches logs with geographic information about IP addresses **without creating high-cardinality labels**. This provides valuable threat intelligence while maintaining low stream counts.

### What GeoIP Provides

When enabled, Alloy adds these fields to log lines:
- `geoip_country_name` - "United States"
- `geoip_country_code` - "US"
- `geoip_city_name` - "Los Angeles"
- `geoip_location_latitude` - "34.0522"
- `geoip_location_longitude` - "-118.2437"

### Enabled For

- **Router firewall logs** (Oracle01) - Track attack sources
- **Suricata IDS logs** (Oracle02) - Identify threat origins
- **Nginx access logs** (Oracle02) - Understand visitor geography

### Setup Required

1. **Install GeoIP database** - See [GeoIP Setup Guide](../docs/geoip-setup.md)
2. **Mount database in containers** - Already configured in docker-compose files
3. **Deploy Alloy** - GeoIP processing automatically enabled

### Querying GeoIP Data

GeoIP fields are in log content, **NOT labels**. Query with LogQL:

```logql
# Suricata alerts from China
{job="suricata", event_type="alert"} | json | geoip_country_name="China"

# Nginx visitors from London
{job="nginx_access"} | json | geoip_city_name="London"

# Router firewall blocks by country
{job="openwrt_syslog"} | logfmt | geoip_country_name="Russia"

# Top attacking countries
topk(10, sum by (geoip_country_name)
  (count_over_time({job="suricata", event_type="alert"}[24h]
  | json | geoip_country_name!="")))
```

### Why Not Use GeoIP as Labels?

❌ **DON'T DO THIS:**
```hcl
stage.labels {
  values = {
    country = "geoip_country_name",  // 200+ countries
    city    = "geoip_city_name",     // 10,000+ cities
  }
}
```
**Result:** Stream explosion! 10,000+ streams = 429 errors

✅ **DO THIS (Already Implemented):**
```hcl
stage.geoip {
  db     = "/geoip/GeoLite2-City.mmdb"
  source = "src_ip"
}
// GeoIP fields added to log content, not as labels
```
**Result:** Low streams, queryable data!

---

## 📦 Volume Mounts

### Overview

Alloy containers require several volume mounts for data access and persistence. This section explains each mount's purpose.

### Oracle01 Volume Mounts

```yaml
volumes:
  # Alloy configuration
  - ./configs/oracle01-alloy.alloy:/etc/alloy/config.alloy:ro

  # Persistent data volume (positions, WAL, etc.)
  - alloy-data:/var/lib/alloy/data

  # GeoIP database for IP geolocation
  - /opt/geoip/GeoLite2-City.mmdb:/geoip/GeoLite2-City.mmdb:ro

  # Docker socket for service discovery
  - /var/run/docker.sock:/var/run/docker.sock:ro

  # System logs
  - /var/log:/var/log:ro

  # Docker container logs (direct access)
  - /var/lib/docker/containers:/var/lib/docker/containers:ro
```

### Oracle02 Volume Mounts

```yaml
volumes:
  # Alloy configuration
  - ./configs/oracle02-alloy.alloy:/etc/alloy/config.alloy:ro

  # Persistent data volume (positions, WAL, etc.)
  - alloy-data:/var/lib/alloy/data

  # GeoIP database for IP geolocation
  - /opt/geoip/GeoLite2-City.mmdb:/geoip/GeoLite2-City.mmdb:ro

  # Docker socket (optional but recommended)
  - /var/run/docker.sock:/var/run/docker.sock:ro

  # System logs
  - /var/log:/var/log:ro

  # Nginx logs (multiple websites)
  - /var/www/html:/var/www/html:ro

  # Suricata IDS logs
  - /var/log/suricata:/var/log/suricata:ro

  # Docker container logs (direct access)
  - /var/lib/docker/containers:/var/lib/docker/containers:ro
```

### Volume Purpose Explained

| Volume | Purpose | Required? | Notes |
|--------|---------|-----------|-------|
| **Config file** | Alloy configuration | ✅ Required | Read-only (`:ro`) |
| **Data volume** | Persistent positions, WAL | ✅ Required | Survives container restart |
| **GeoIP database** | IP geolocation | ⚠️ GeoIP only | Required if using GeoIP processing |
| **Docker socket** | Service discovery | 🔧 Optional | Enables dynamic Docker service detection |
| **System logs** | `/var/log` access | 🔧 As needed | Only if collecting system logs |
| **Nginx logs** | Web server logs | 🔧 Oracle02 only | Only on web servers |
| **Suricata logs** | IDS logs | 🔧 Oracle02 only | Only where Suricata runs |
| **Container logs** | Direct log access | 🔧 Optional | Alternative to Docker API |

### Security Considerations

**Read-Only Mounts (`:ro`):**
- Prevents Alloy from modifying files
- Use for all file/directory mounts
- Exception: Data volume needs write access

**Docker Socket (`/var/run/docker.sock`):**
- ⚠️ Grants container access to Docker API
- Can list/inspect containers
- Cannot create/destroy containers (no `--privileged`)
- Useful for dynamic service discovery
- Optional - remove if not needed

**Data Volume Permissions:**
- Alloy runs as `nobody` user (UID 65534)
- Data volume owned by Docker
- No host permission changes needed

---

## 📛 Container Naming Convention

### Standard Naming

All containers in the TeckGlobal stack use this naming convention:

**Format:** `<service>-orc<number>`

**Examples:**
- `alloy-orc01` - Alloy on Oracle01
- `alloy-orc02` - Alloy on Oracle02
- `loki-orc01` - Loki on Oracle01
- `mimir-orc01` - Mimir on Oracle01
- `suricata-orc02` - Suricata on Oracle02

### Why "orc" Instead of "oracle"?

- **Short and memorable** - Easier to type in commands
- **Consistent** - Same length for all containers
- **Clear** - Still obviously refers to Oracle servers

### Container References

Update any scripts or documentation that reference old names:

| Old Name | New Name |
|----------|----------|
| `alloy` | `alloy-orc01` |
| `alloy-oracle02` | `alloy-orc02` |
| `loki-oracle01` | `loki-orc01` |

---

## ✅ Verification

### Check Alloy Health

**Alloy UI:**
```
Oracle01: http://10.0.206.10:12345
Oracle02: http://10.0.206.20:12346
```

**Metrics Endpoint:**
```bash
# Oracle01
curl http://10.0.206.10:12345/metrics | grep -E '(loki_|prometheus_)'

# Oracle02
curl http://10.0.206.20:12346/metrics | grep -E '(loki_|prometheus_)'
```

### Check Loki Stream Count

```bash
# Get stream count
curl -s "http://10.0.206.10:3100/loki/api/v1/streams" | jq '. | length'

# Expected: < 100 streams
# Before: 10,000+ streams
```

### Check for Errors

```bash
# Check Loki logs for 429 errors (should be none!)
docker logs loki-oracle01 2>&1 | grep "429"

# Check Alloy logs
docker logs alloy | tail -50
docker logs alloy-oracle02 | tail -50
```

### Test LogQL Queries

**In Grafana Explore:**

```logql
# Test nginx logs from Oracle02
{job="nginx_access", host="oracle02"}

# Test Suricata alerts
{job="suricata", event_type="alert"}

# Test router firewall logs
{job="openwrt_syslog"}

# Test high-cardinality field query
{job="suricata"} | json | src_ip="45.225.192.88"
```

---

## 🔧 Troubleshooting

### Logs Not Appearing in Loki

**1. Check Alloy is running:**
```bash
docker ps | grep alloy
```

**2. Check Alloy logs for errors:**
```bash
docker logs alloy -f
```

**3. Verify Loki is accessible:**
```bash
curl http://localhost:3100/ready
```

**4. Test Loki ingestion manually:**
```bash
curl -X POST "http://localhost:3100/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d '{
    "streams": [{
      "stream": {"job": "test"},
      "values": [["'$(date +%s)'000000000", "test message"]]
    }]
  }'
```

### High Stream Count

**1. Query Loki for stream labels:**
```bash
curl -s "http://localhost:3100/loki/api/v1/label" | jq
```

**2. Find labels with high cardinality:**
```bash
curl -s "http://localhost:3100/loki/api/v1/label/src_ip/values" | jq '. | length'
```

**3. Review Alloy config - ensure high-cardinality fields are NOT in `stage.labels`**

### Connection Refused (Oracle02 → Oracle01)

**1. Check network connectivity:**
```bash
ping 10.0.206.10
telnet 10.0.206.10 3100
```

**2. Check firewall:**
```bash
# On Oracle01
sudo ufw status | grep 3100
```

**3. Verify Loki is listening:**
```bash
# On Oracle01
ss -tuln | grep 3100
```

### Performance Issues

**1. Check Alloy resource usage:**
```bash
docker stats alloy
```

**2. Reduce scrape frequency (if metrics collection is slow):**
Edit `configs/oracle01-alloy.alloy`:
```hcl
prometheus.scrape "node_exporter" {
  scrape_interval = "30s"  // Increase from default 15s
  ...
}
```

**3. Check Loki performance:**
```bash
docker stats loki-oracle01
```

---

## 📚 Additional Resources

- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Loki Best Practices](https://grafana.com/docs/loki/latest/best-practices/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/query/)
- [Cardinality Guide](../docs/monitoring/CARDINALITY-GUIDE.md)

---

**Built with ❤️ by TeckGlobal** | [GitHub](https://github.com/teckglobal/teckglobal-cloud-dmz-stack)
