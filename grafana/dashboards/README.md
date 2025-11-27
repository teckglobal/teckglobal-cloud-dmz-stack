# Grafana Dashboards

Pre-built dashboards for the TeckGlobal Cloud DMZ Stack monitoring infrastructure.

## Available Dashboards

### Network Overview

**File:** [network-overview.json](network-overview.json)
**UID:** `teckglobal-network-overview`

Comprehensive overview dashboard for the entire infrastructure with balanced visual and technical details.

#### Panels Included:

**Quick Stats Row:**
- **Servers Online** - Count of servers reporting to node_exporter
- **Active Containers** - Number of running Docker containers
- **Log Ingestion Rate** - Current logs per second being ingested to Loki
- **IDS Alerts (Last Hour)** - Suricata IDS alert count from last hour

**System Resources Row:**
- **CPU Usage by Server** - CPU utilization percentage per server (time series)
- **Memory Usage by Server** - Memory usage percentage per server (time series)
- **Disk Usage by Server** - Disk usage percentage per server and mountpoint (time series)

**Network Activity & Security Row:**
- **Firewall Activity by Country** - Table showing firewall events by country using GeoIP data
- **Top Source IPs** - Top 10 source IPs with their city and country from GeoIP enrichment

**Log Sources & Volume Row:**
- **Log Volume by Job** - Stacked time series showing log ingestion rate per job (nginx, suricata, syslog, etc.)
- **Recent Log Entries** - Live log viewer showing the most recent logs from all sources

#### Data Sources Required:

- **Loki** - Data source UID: `loki`
- **Mimir (Prometheus)** - Data source UID: `mimir`

#### Usage:

This dashboard auto-refreshes every 10 seconds and shows the last 1 hour of data by default. All panels are interactive and support drilling down into specific metrics or logs.

**GeoIP Queries:**
- The "Firewall Activity by Country" panel uses GeoIP enrichment from router syslog
- The "Top Source IPs" panel shows city and country for each source IP
- All GeoIP data is queried from log content (not labels) using `| json | geoip_*`

---

## Dashboard Installation

### Automatic (Docker Compose)

If using the provided docker-compose.yml, dashboards are automatically provisioned from this directory.

Ensure your Grafana service has this volume mount:

```yaml
services:
  grafana:
    volumes:
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
```

### Manual Import

1. Open Grafana UI (http://your-server:3000)
2. Navigate to **Dashboards** → **Import**
3. Click **Upload JSON file**
4. Select the dashboard JSON file
5. Choose the correct data sources (Loki and Mimir)
6. Click **Import**

---

## Creating Custom Dashboards

### Best Practices

1. **Use Low-Cardinality Labels** - Only filter by job, host, event_type in Loki queries
2. **Query High-Cardinality Fields with LogQL** - Use `| json | field="value"` for IPs, cities, etc.
3. **Set Appropriate Refresh Rates** - Use 10s-30s for overview dashboards, 5s for security dashboards
4. **Use Transformations** - Convert Loki label results to table columns with `labelsToFields`
5. **Add Context** - Include GeoIP data in network/security panels for geographic context

### Example Queries

**Loki - Firewall logs by country:**
```logql
{job=~".*_syslog"} | json | geoip_country_name!=""
```

**Loki - Top source IPs:**
```logql
topk(10, sum by (SRC, geoip_city_name) (count_over_time({job=~".*_syslog"} | json [$__auto])))
```

**Prometheus - CPU usage:**
```promql
(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[$__rate_interval])) by (instance)) * 100
```

**Prometheus - Memory usage:**
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

---

## Troubleshooting

### Dashboard shows "No Data"

**Check:**
1. Verify data sources are configured in Grafana (Loki and Mimir)
2. Ensure data source UIDs match (`loki` and `mimir`)
3. Confirm logs are being ingested to Loki
4. Check Alloy is sending metrics to Mimir

**Test queries manually:**
```bash
# Test Loki
curl -G "http://10.0.206.10:3100/loki/api/v1/query" \
  --data-urlencode 'query={job=~".+"}' --data-urlencode 'limit=10'

# Test Mimir
curl "http://10.0.206.10:9009/prometheus/api/v1/query?query=up"
```

### GeoIP fields are empty

**Check:**
1. GeoIP database is mounted in Alloy containers (`/geoip/GeoLite2-City.mmdb`)
2. Alloy configs have `stage.geoip` blocks for syslog, nginx, suricata
3. Alloy configs have `stage.pack` to embed GeoIP fields in log content
4. Query uses `| json` parser before filtering GeoIP fields

**Test query:**
```logql
{job="oraclewrt_syslog"} | json | geoip_country_name!=""
```

### Panels show errors

**Common Issues:**
- **"Template variables could not be initialized"** - Dashboard has no template variables, ignore this
- **"Failed to upgrade legacy queries"** - Dashboard format is current, safe to dismiss
- **"Datasource not found"** - Update data source UIDs in dashboard JSON to match your setup

---

## Future Dashboards

Planned dashboards for this stack:

- **Suricata Security Dashboard** - IDS/IPS alerts, threat analysis, attack sources map
- **Web Traffic Analysis** - Nginx metrics, visitor geography, response times
- **Container Monitoring** - Docker resource usage, container health, restart counts
- **Router Performance** - OpenWrt metrics, WireGuard VPN stats, interface traffic

---

**Built with ❤️ by TeckGlobal** | [GitHub](https://github.com/teckglobal/teckglobal-cloud-dmz-stack)
