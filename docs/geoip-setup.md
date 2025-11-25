# GeoIP Database Setup Guide

> **Add IP geolocation capabilities to your monitoring stack**

This guide explains how to set up MaxMind's GeoLite2 database for IP geolocation in Grafana Alloy. The GeoIP database enriches your logs with geographic information about IP addresses **without creating high-cardinality labels**.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Method 1: Manual Download](#method-1-manual-download-simple)
- [Method 2: geoipupdate Package](#method-2-geoipupdate-package-automated)
- [Method 3: Docker Sidecar](#method-3-docker-sidecar-containerized)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Overview

### What is GeoIP?

GeoIP databases map IP addresses to geographic locations (country, city, coordinates, ISP, etc.). In the TeckGlobal stack, we use MaxMind's **GeoLite2-City** database to enrich:

- **Router firewall logs** - Track attack sources by country
- **Suricata IDS logs** - Identify malicious traffic origins
- **Nginx access logs** - Understand visitor geography

### Why GeoLite2-City?

- **Free** - No cost for personal/internal use
- **Accurate** - City-level precision for most IPs
- **Updated regularly** - New releases weekly
- **Lightweight** - ~60MB compressed, ~150MB uncompressed

### How Alloy Uses GeoIP

Alloy's `stage.geoip` processor enriches log lines with geoip_* fields:
- `geoip_country_name` - "United States"
- `geoip_city_name` - "Los Angeles"
- `geoip_location_latitude` - "34.0522"
- `geoip_location_longitude` - "-118.2437"

**CRITICAL:** These fields are added to log content, **NOT as labels**, preventing cardinality explosion.

Query with LogQL:
```logql
{job="suricata"} | json | geoip_country_name="China"
{job="nginx_access"} | json | geoip_city_name="London"
```

---

## Prerequisites

### 1. Create MaxMind Account

1. Visit https://www.maxmind.com/en/geolite2/signup
2. Sign up for a free account
3. Verify your email address
4. Log in to your account

### 2. Generate License Key

1. Go to **Account** → **Manage License Keys**
2. Click **Generate new license key**
3. Name it (e.g., "TeckGlobal Monitoring")
4. Select **GeoIP Update** for the license type
5. Click **Confirm**
6. **SAVE THE LICENSE KEY** - You can't retrieve it later!

---

## Method 1: Manual Download (Simple)

Best for: Testing, one-time setup, or environments without automation needs.

### Step 1: Download the Database

Using your MaxMind account credentials:

```bash
# Create directory
sudo mkdir -p /opt/geoip
cd /opt/geoip

# Download latest GeoLite2-City database
# Replace YOUR_LICENSE_KEY with your actual key
sudo wget "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=YOUR_LICENSE_KEY&suffix=tar.gz" -O GeoLite2-City.tar.gz

# Extract
sudo tar -xzf GeoLite2-City.tar.gz
sudo mv GeoLite2-City_*/GeoLite2-City.mmdb ./
sudo rm -rf GeoLite2-City_* GeoLite2-City.tar.gz

# Set permissions
sudo chmod 644 GeoLite2-City.mmdb
sudo chown root:root GeoLite2-City.mmdb
```

### Step 2: Verify

```bash
ls -lh /opt/geoip/GeoLite2-City.mmdb
```

Expected output:
```
-rw-r--r-- 1 root root 70M Jan 15 10:00 /opt/geoip/GeoLite2-City.mmdb
```

### Step 3: Configure Docker Volume

Ensure your docker-compose files mount the database:

```yaml
volumes:
  - /opt/geoip/GeoLite2-City.mmdb:/geoip/GeoLite2-City.mmdb:ro
```

**Note:** Manual downloads need to be updated manually (weekly recommended).

---

## Method 2: geoipupdate Package (Automated)

Best for: Production environments needing automatic updates.

### Ubuntu/Debian

**Step 1: Install geoipupdate**

```bash
# Add PPA repository
sudo add-apt-repository ppa:maxmind/ppa
sudo apt update

# Install geoipupdate
sudo apt install geoipupdate
```

**Step 2: Configure geoipupdate**

Edit `/etc/GeoIP.conf`:

```bash
sudo nano /etc/GeoIP.conf
```

Update these fields:
```conf
AccountID YOUR_ACCOUNT_ID
LicenseKey YOUR_LICENSE_KEY
EditionIDs GeoLite2-City

# Download directory
DatabaseDirectory /opt/geoip
```

**Step 3: Test Manual Update**

```bash
sudo geoipupdate -v
```

**Step 4: Setup Automatic Updates**

Create cron job for weekly updates:

```bash
sudo crontab -e
```

Add this line (runs every Wednesday at 3 AM):
```cron
0 3 * * 3 /usr/bin/geoipupdate
```

### CentOS/RHEL

```bash
# Install
sudo yum install geoipupdate

# Configure (same as Ubuntu above)
sudo nano /etc/GeoIP.conf

# Test
sudo geoipupdate -v

# Setup cron (same as Ubuntu above)
```

---

## Method 3: Docker Sidecar (Containerized)

Best for: Fully containerized infrastructure, consistency across environments.

### Create GeoIP Updater Container

**1. Create docker-compose.yml for updater:**

```yaml
# /opt/geoip-updater/docker-compose.yml
services:
  geoip-updater:
    image: maxmindinc/geoipupdate:latest
    container_name: geoip-updater
    restart: unless-stopped

    environment:
      GEOIPUPDATE_ACCOUNT_ID: "YOUR_ACCOUNT_ID"
      GEOIPUPDATE_LICENSE_KEY: "YOUR_LICENSE_KEY"
      GEOIPUPDATE_EDITION_IDS: "GeoLite2-City"
      GEOIPUPDATE_FREQUENCY: "168"  # Update every 7 days (in hours)

    volumes:
      - /opt/geoip:/usr/share/GeoIP

    # Optional: Resource limits
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 128M
```

**2. Deploy:**

```bash
cd /opt/geoip-updater
docker-compose up -d
```

**3. Verify:**

```bash
# Check logs
docker logs geoip-updater

# Verify database exists
ls -lh /opt/geoip/GeoLite2-City.mmdb
```

**4. Monitor:**

The container will automatically update the database every 7 days.

---

## Verification

### 1. Check Database File

```bash
ls -lh /opt/geoip/GeoLite2-City.mmdb
```

Expected:
- File size: 60-80 MB
- Permissions: `644` (readable by all)
- Owner: `root:root`

### 2. Test in Alloy Container

```bash
# Check if Alloy can access the database
docker exec alloy-orc01 ls -lh /geoip/GeoLite2-City.mmdb

# Expected output:
# -rw-r--r-- 1 root root 70M Jan 15 10:00 /geoip/GeoLite2-City.mmdb
```

### 3. Query Logs with GeoIP Data

After deploying Alloy with GeoIP processing:

```bash
# Query Suricata logs with GeoIP country
curl -G -s "http://10.0.206.10:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="suricata"} | json | geoip_country_name!=""' \
  --data-urlencode 'limit=5' | jq

# Query nginx logs from specific city
curl -G -s "http://10.0.206.10:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="nginx_access"} | json | geoip_city_name="London"' \
  --data-urlencode 'limit=5' | jq
```

### 4. Test in Grafana

Create LogQL query in Grafana Explore:

```logql
{job="suricata", event_type="alert"}
| json
| geoip_country_name != ""
| line_format "{{.src_ip}} from {{.geoip_city_name}}, {{.geoip_country_name}}"
```

---

## Troubleshooting

### Database File Not Found

**Symptom:** Alloy logs show "GeoIP database not found"

**Solutions:**
```bash
# 1. Verify file exists on host
ls -lh /opt/geoip/GeoLite2-City.mmdb

# 2. Check docker volume mount in docker-compose.yml
# Should have:
# - /opt/geoip/GeoLite2-City.mmdb:/geoip/GeoLite2-City.mmdb:ro

# 3. Restart Alloy container
docker restart alloy-orc01 alloy-orc02
```

### Permission Denied

**Symptom:** Alloy can't read the database file

**Solution:**
```bash
# Fix permissions
sudo chmod 644 /opt/geoip/GeoLite2-City.mmdb
sudo chown root:root /opt/geoip/GeoLite2-City.mmdb

# Restart Alloy
docker restart alloy-orc01 alloy-orc02
```

### Database is Old

**Symptom:** GeoIP data is outdated

**Solution:**
```bash
# Check file modification time
stat /opt/geoip/GeoLite2-City.mmdb

# Method 1 users: Re-download manually
cd /opt/geoip
sudo wget "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=YOUR_LICENSE_KEY&suffix=tar.gz" -O GeoLite2-City.tar.gz
sudo tar -xzf GeoLite2-City.tar.gz
sudo mv GeoLite2-City_*/GeoLite2-City.mmdb ./
sudo rm -rf GeoLite2-City_* GeoLite2-City.tar.gz

# Method 2 users: Run geoipupdate
sudo geoipupdate -v

# Method 3 users: Restart updater container
docker restart geoip-updater
```

### geoipupdate Fails

**Symptom:** `geoipupdate` command fails with authentication error

**Solutions:**
1. Verify Account ID and License Key in `/etc/GeoIP.conf`
2. Ensure license key is for "GeoIP Update" product type
3. Check MaxMind account is active and email verified

### No GeoIP Fields in Logs

**Symptom:** Logs don't contain geoip_* fields

**Solutions:**
```bash
# 1. Verify Alloy config has stage.geoip blocks
docker exec alloy-orc01 cat /etc/alloy/config.alloy | grep -A 3 "stage.geoip"

# 2. Check Alloy logs for GeoIP errors
docker logs alloy-orc01 2>&1 | grep -i geoip

# 3. Ensure source field has valid IPs
# Example: source = "src_ip" or source = "remote_addr"

# 4. Restart Alloy after config changes
docker restart alloy-orc01 alloy-orc02
```

---

## Best Practices

1. **Update Regularly**: MaxMind releases updates weekly. Keep your database current.
2. **Monitor Updates**: Check logs to ensure automatic updates are working.
3. **Backup Database**: Keep a copy in case of corruption (though easily re-downloadable).
4. **Use Read-Only Mounts**: Mount database as `:ro` in Docker to prevent accidental modification.
5. **Don't Use GeoIP Fields as Labels**: Always keep geoip_* fields in log content, never as Loki labels (high cardinality!).

---

## Additional Resources

- [MaxMind GeoLite2 Documentation](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data)
- [geoipupdate GitHub](https://github.com/maxmind/geoipupdate)
- [Grafana Alloy GeoIP Stage](https://grafana.com/docs/alloy/latest/reference/components/loki.process/#stagegeoip-block)
- [MaxMind License Key Management](https://www.maxmind.com/en/accounts/current/license-key)

---

**Built with ❤️ by TeckGlobal** | [GitHub](https://github.com/teckglobal/teckglobal-cloud-dmz-stack)
