# Grafana Mimir - Metrics Storage

Prometheus-compatible long-term metrics storage for the TeckGlobal monitoring stack.

## Overview

Grafana Mimir provides:
- Long-term storage for Prometheus metrics
- Horizontal scalability
- Multi-tenancy support (disabled in this config)
- High availability (when deployed in microservices mode)

## Deployment

### Configuration

The configuration file is located at: [configs/mimir-config.yaml](configs/mimir-config.yaml)

**Mode:** Monolithic (all components in one container)

**Key Settings:**
- **Target:** `all` (runs all Mimir components)
- **Storage:** Filesystem at `/data/mimir`
- **Retention:** 30 days
- **Ports:**
  - 9009 (HTTP API/remote_write)
  - 9095 (gRPC)
  - 7946 (Memberlist)

### Deploy Mimir

```bash
cd /Users/eugenehedges/Desktop/teckglobal-cloud-dmz-stack/grafana-mimir
docker-compose up -d
```

### Verify Deployment

```bash
# Check container status
docker ps | grep mimir

# View logs
docker logs -f mimir-orc01

# Check readiness
curl http://localhost:9009/ready

# Check metrics endpoint
curl http://localhost:9009/metrics
```

### Stop/Restart

```bash
# Stop
docker-compose down

# Restart
docker-compose restart

# Rebuild and restart
docker-compose down && docker-compose up -d
```

## Integration

### Grafana Alloy

Alloy sends metrics to Mimir via Prometheus remote_write:

```hcl
prometheus.remote_write "mimir" {
  endpoint {
    url = "http://mimir-orc01:9009/api/v1/push"
  }
}
```

### Query Metrics

Query metrics using Prometheus-compatible API:

```bash
# Query all up metrics
curl -X POST http://localhost:9009/prometheus/api/v1/query \
  -d 'query=up'

# Query with time range
curl -X POST http://localhost:9009/prometheus/api/v1/query_range \
  -d 'query=up' \
  -d 'start=2024-01-01T00:00:00Z' \
  -d 'end=2024-01-02T00:00:00Z' \
  -d 'step=15s'
```

### Grafana Data Source

Add Mimir as a Prometheus data source in Grafana:

- **URL:** `http://mimir-orc01:9009/prometheus`
- **Type:** Prometheus
- **Access:** Server (default)

## Troubleshooting

### Error: "unknown service cortex.Ingester"

**Cause:** Mimir running without proper monolithic configuration

**Fix:**
1. Ensure config file exists: `./configs/mimir-config.yaml`
2. Ensure command includes: `-target=all`
3. Restart container: `docker-compose restart`

### Error: "connection refused"

**Cause:** Mimir not running or port not accessible

**Fix:**
```bash
# Check if container is running
docker ps | grep mimir

# Check logs for errors
docker logs mimir-orc01

# Verify port is listening
ss -tlnp | grep 9009
```

### High Memory Usage

**Cause:** Mimir caches data in memory for performance

**Fix:** Adjust resource limits in docker-compose.yml:
```yaml
deploy:
  resources:
    limits:
      memory: 2G
```

### Data Loss After Restart

**Cause:** Volume not properly mounted

**Fix:** Verify volume in docker-compose.yml:
```yaml
volumes:
  - mimir_data:/data/mimir
```

Check volume exists:
```bash
docker volume ls | grep mimir
```

## Monitoring

Monitor Mimir itself by scraping its `/metrics` endpoint:

```hcl
prometheus.scrape "mimir" {
  targets = [
    {"__address__" = "mimir-orc01:9009", "instance" = "mimir-orc01"},
  ]
  forward_to = [prometheus.remote_write.mimir.receiver]
}
```

## Advanced Configuration

### Change Retention Period

Edit `configs/mimir-config.yaml`:

```yaml
blocks_storage:
  tsdb:
    retention_period: 90d  # Change from 30d to 90d
```

Restart container:
```bash
docker-compose restart
```

### Enable Multi-tenancy

Edit `configs/mimir-config.yaml`:

```yaml
multitenancy_enabled: true
```

Configure Alloy with tenant header:
```hcl
prometheus.remote_write "mimir" {
  endpoint {
    url = "http://mimir-orc01:9009/api/v1/push"
    headers = {
      "X-Scope-OrgID" = "tenant1"
    }
  }
}
```

## Resources

- [Grafana Mimir Documentation](https://grafana.com/docs/mimir/latest/)
- [Configuration Reference](https://grafana.com/docs/mimir/latest/references/configuration-parameters/)
- [Prometheus Remote Write](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write)
