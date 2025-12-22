# TeckGlobal Cloud DMZ Stack

> **Secure Cloud Infrastructure with OpenWrt DMZ Gateway + Comprehensive Monitoring**

A production-ready infrastructure stack featuring OpenWrt as a cloud DMZ gateway, complete with VPN connectivity, security monitoring (Suricata IDS), and unified observability (Grafana, Loki, Mimir, Alloy).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?logo=docker&logoColor=white)](https://www.docker.com/)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-00B5E2?logo=openwrt&logoColor=white)](https://openwrt.org/)
[![Grafana](https://img.shields.io/badge/grafana-%23F46800.svg?logo=grafana&logoColor=white)](https://grafana.com/)

---

## 🌟 What Makes This Unique?

This stack introduces a **cloud DMZ pattern** using OpenWrt as a virtual router/firewall in cloud environments (OCI, AWS, Azure, GCP). All traffic flows through OpenWrt, providing:

- **🛡️ Enterprise-grade security** at the network edge
- **🔒 WireGuard VPN** for encrypted site-to-site and remote access
- **👁️ Complete visibility** with Suricata IDS, firewall logging, and GeoIP analysis
- **📊 Unified monitoring** of infrastructure, applications, and security events
- **🚀 Easy deployment** across any cloud provider

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Use Cases](#use-cases)
- [Components](#components)
- [Documentation](#documentation)
- [Cloud Provider Guides](#cloud-provider-guides)
- [Contributing](#contributing)
- [License](#license)

---

## 📍 Current Status

**Last Updated:** December 21, 2025
**Production Stack:** Fully Operational ✅

### Live Infrastructure

| Server | IP | Role | Services |
|--------|-----|------|----------|
| **Oracle01** | 10.0.206.10 | Monitoring Hub | Grafana + Loki + Mimir + Alloy |
| **Oracle02** | 10.0.206.20 | Application Server | Nginx + Redis HA + Suricata IDS |
| **OracleWrt** | 10.0.5.1 | Cloud DMZ Router | OpenWrt + WireGuard + Firewall |
| **OpenWrt** | 10.0.100.1 | Local Gateway | OpenWrt + WireGuard + VPN |
| **Tecklord01** | 10.48.1.15 | Dev Server | Docker Swarm + MariaDB |

### Recent Achievements

- ✅ **7 Production Dashboards** - NGINX analytics, Redis HA, Suricata IDS, Router monitoring
- ✅ **GeoIP World Maps** - Visitor geolocation on all web and security dashboards
- ✅ **Redis HA Cluster** - Sentinel-managed master/replica with automatic failover
- ✅ **Docker DNS Sync** - Automatic container DNS registration across Swarm cluster
- ✅ **Migrated to Grafana Alloy** - Unified agent replacing Promtail

### Active Data Collection

- **Firewall Logs:** 2 routers streaming syslog with GeoIP enrichment (ports 1515, 1516)
- **Web Traffic:** Nginx access logs with visitor geolocation from 10+ websites
- **Security Events:** Suricata IDS alerts with threat source mapping
- **System Metrics:** CPU, memory, disk, network from all infrastructure
- **Container Metrics:** Docker resource usage via cAdvisor

### What's Working Right Now

```
Live Log Sources: 8 active streams
├─ openwrt_syslog (local router)
├─ oraclewrt_syslog (cloud router)
├─ nginx_access (10+ websites)
├─ nginx_error
├─ suricata (IDS/IPS)
├─ syslog (system logs)
└─ system_logs

Metrics Collection: 5 servers monitored
└─ node_exporter, cAdvisor, collectd
```

---

## ✨ Features

### Network & Security
- ✅ **OpenWrt Cloud DMZ** - Virtual router/firewall at cloud network edge
- ✅ **WireGuard VPN** - Site-to-site tunnels + mobile client support
- ✅ **Suricata IDS/IPS** - Real-time threat detection and prevention
- ✅ **Zone-based Firewall** - Granular network segmentation
- ✅ **DNS over TLS (Stubby)** - Encrypted DNS queries
- ✅ **GeoIP Analysis** - Geographic threat intelligence

### Monitoring & Observability
- ✅ **Grafana Alloy** - Unified agent for logs and metrics
- ✅ **Grafana Loki** - Scalable log aggregation
- ✅ **Grafana Mimir** - Long-term Prometheus metrics storage
- ✅ **Low-Cardinality Logging** - Optimized for Loki's architecture
- ✅ **Pre-built Dashboards** - System, Docker, nginx, security monitoring
- ✅ **Centralized Logging** - Single pane of glass for all infrastructure

### Infrastructure
- ✅ **Docker-based** - Easy deployment with docker-compose
- ✅ **Multi-server Support** - Scales from 1 to 100+ servers
- ✅ **Infrastructure as Code** - Reproducible deployments
- ✅ **Cloud Provider Guides** - OCI, AWS, Azure, GCP deployment docs
- ✅ **Backup/Restore Scripts** - Data protection automation

---

## 🏗️ Architecture

### Network Topology

## Network Architecture Overview

```
                                               Point to Point
                                                  MTU 1388
                       INTERNET <============<VPN WIREGUARD TUNNEL>============> INTERNET
                          │                                                         │
                          ▼                                                         ▼
              ┌───────────▼─────────┐                                    ┌──────────▼──────────┐
              │    OCI - Gateway    │                                    │  Local Gateway      │ DDNS
              │  WAN:201.xxx.xxx.xxx│ Static IP                          │  WAN: 97.xxx.xx.xxx │ Dynamic IP
              │  OpenWrt Router     │                                    │  OpenWrt Router     │
              │   (10.0.5.1 wg0 )   │                                    │  (10.0.100.1 wg0)   │
              └──────────┬──────────┘                                    └──────────┬──────────┘
                         │                                                          │
                         │                                                          │
                         │                                                          │
                 ┌───────▼────────┐                                        ┌────────▼────────┐
                 │ Local Network  │                                        │                 │
                 │ Lan            │                                 ┌──────▼─────────┐┌──────▼────────┐
                 │ 10.0.206.0/24  │                                 │ Local Network  ││ Local Network │
                 └────────────────┘                                 │     Secure     ││    Lan DEV    │
                         │                                          │  10.48.1.0/24  ││192.168.10.0/23│
            ┌────────────┴────────────┐                             └────────────────┘└───────────────┘
            │                         │                                     │                │
    ┌───────▼──────┐          ┌───────▼───────┐                             │                ┴─────────┐
    │   Ubuntu     │          │   Ubuntu      │                             │                          │
    │   oracle01   │          │   oracle02    │                     ┌───────▼──────┐           ┌───────▼─────────┐
    │  10.0.206.10 │          │  10.0.206.20  │                     │   Debian VM  │           │   DEV  TEST     │
    │  (10G RAM)   │          │  (12G RAM)    │                     │  tecklord01  │           │    DEVIL01      │128GB RAM
    └──────────────┘          └───────────────┘                     │  10.48.1.15  │           │192.168.10.0/24  │64 Epyc
                                                                    │  (4G RAM)    │           │192.168.20.0/24  │2 4790 TI 32GB
                                                                    └──────────────┘           └─────────────────┘12 TB STORAGE
                                                                 (VMware Fusion on Mac)        ( DEVS PLAYGROUND )
```

### Data Flow

**Logs:**
```
OpenWrt Routers → Alloy (syslog:1515, syslog:1516) → Loki (firewall logs + GeoIP)
Servers         → Alloy (file collection)          → Loki (app logs, system logs)
Nginx           → Alloy (access/error logs)        → Loki (web traffic + GeoIP)
Suricata        → Alloy (eve.json)                 → Loki (IDS alerts + GeoIP)
```

**Metrics:**
```
Servers       → Alloy         → Mimir (via prometheus.remote_write)
Docker        → cAdvisor      → Alloy → Mimir
node_exporter → Alloy         → Mimir
collectd      → Alloy         → Mimir (OpenWrt metrics)
```

**GeoIP Enrichment Pipeline:**
```
Raw Log → stage.logfmt/json → stage.geoip → stage.pack → Loki
                                    ↓             ↓
                            GeoLite2-City    JSON Embed
                            (MaxMind DB)     (queryable)

Query: {job="..."} | json | geoip_country_name="China"
```

---

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose (or Docker Swarm for HA)
- Linux server with 4GB+ RAM (Ubuntu 22.04+ or Debian 11+)
- (Optional) OpenWrt router for DMZ gateway

### 1. Clone and Deploy Monitoring Stack

```bash
# Clone the repository
git clone https://github.com/teckglobal/teckglobal-cloud-dmz-stack
cd teckglobal-cloud-dmz-stack

# Deploy Loki (log aggregation)
cd grafana-loki && docker-compose up -d && cd ..

# Deploy Mimir (metrics storage)
cd grafana-mimir && docker-compose up -d && cd ..

# Deploy Alloy (unified collection agent)
cd grafana-alloy && docker-compose -f docker-compose-oracle01.yml up -d && cd ..
```

### 2. Import Grafana Dashboards

Dashboards are located in `grafana/dashboards/`. Import via Grafana UI:

1. Open Grafana: `http://your-server:3000`
2. Go to **Dashboards** → **Import**
3. Upload JSON file or paste dashboard ID
4. Select your datasources (Loki, Prometheus/Mimir)

See [grafana/dashboards/README.md](grafana/dashboards/README.md) for full dashboard documentation.

### 3. Access Points

| Service | URL | Default Login |
|---------|-----|---------------|
| Grafana | http://your-server:3000 | admin/admin |
| Loki API | http://your-server:3100 | - |
| Alloy UI | http://your-server:12345 | - |
| Mimir API | http://your-server:9009 | - |

---

## 💡 Use Cases

### 1. **Cloud DMZ Gateway**
Deploy OpenWrt as a virtual router in your cloud VPC to control all traffic ingress/egress with enterprise firewall capabilities.

### 2. **Site-to-Site VPN**
Connect multiple cloud regions or connect cloud infrastructure to on-premises networks with WireGuard VPN.

### 3. **Security Monitoring**
Monitor all network traffic with Suricata IDS, analyze threats with GeoIP geolocation, and visualize security events in Grafana dashboards. Track attack sources by country, identify malicious patterns, and respond to threats in real-time.

### 4. **Centralized Logging**
Aggregate logs from all servers, containers, and network devices into a single Loki instance for easy search and analysis.

### 5. **Infrastructure Monitoring**
Track CPU, memory, disk, network metrics across your entire infrastructure with pre-built dashboards.

### 6. **Web Application Monitoring**
Monitor nginx access/error logs, track request rates, analyze status codes, and identify performance issues.

---

## 🧩 Components

### Core Infrastructure

| Component | Purpose | Port |
|-----------|---------|------|
| **OpenWrt** | DMZ Gateway/Router | 22 (SSH), 80/443 (LuCI) |
| **WireGuard** | VPN Tunnels | 62100, 62225 (UDP) |
| **Suricata** | IDS/IPS | N/A (inline) |

### Monitoring Stack

| Component | Purpose | Port |
|-----------|---------|------|
| **Grafana** | Visualization | 3000 |
| **Grafana Loki** | Log Aggregation | 3100 |
| **Grafana Mimir** | Metrics Storage | 9009 |
| **Grafana Alloy** | Unified Agent | 12345 |
| **Prometheus** | Metrics Scraping | 9090 |

### Exporters

| Component | Purpose | Port |
|-----------|---------|------|
| **node_exporter** | System Metrics | 9100 |
| **cAdvisor** | Container Metrics | 9200 |
| **nginx_exporter** | Nginx Metrics | 9113 |

---

## 📚 Documentation

### Getting Started
- [Installation Guide](docs/INSTALLATION.md)
- [GeoIP Setup Guide](docs/geoip-setup.md) - IP geolocation for threat intelligence

### Grafana Dashboards

Pre-built dashboards ready to import. See [grafana/dashboards/README.md](grafana/dashboards/README.md) for details.

| Dashboard | Description | Datasource |
|-----------|-------------|------------|
| **NGINX Web Analytics** | Web traffic, GeoIP maps, visitor stats | Loki |
| **Redis HA - TeckGlobal** | Sentinel cluster monitoring | Redis |
| **Suricata IDS** | Security alerts, threat analysis | Loki |
| **OpenWRT Appliance** | Local router metrics | Prometheus |
| **OracleWRT Appliance** | Cloud gateway metrics | Prometheus |
| **Claude Code Analytics** | AI assistant usage tracking | MySQL |
| **Network Overview** | Infrastructure overview | Loki + Prometheus |

### Component Guides
- [Grafana Alloy](grafana-alloy/README.md) - Unified log/metric collection agent
- [Grafana Loki](grafana-loki/) - Log aggregation and storage
- [Grafana Mimir](grafana-mimir/README.md) - Long-term metrics storage
- [Suricata IDS](suricata/README.md) - Network intrusion detection
- [Redis HA Stack](stacks/REDIS-DEPLOYMENT-GUIDE.md) - Sentinel-managed Redis cluster
- [Docker DNS Sync](docker-dns-sync/) - Automatic container DNS registration

---

## ☁️ Tested Cloud Providers

This stack has been tested and verified on:

- **Oracle Cloud (OCI)** - ✅ Production deployment
- **AWS** - ✅ Tested
- **Home Lab / Bare Metal** - ✅ Tested

OpenWrt can run as a VM on any cloud provider that supports custom images or nested virtualization.

---

## 🎯 Why This Stack?

### Problem: Cloud Network Security is Complex

Most cloud deployments lack proper network-level security:
- ❌ Reliance on provider security groups only
- ❌ No centralized firewall management
- ❌ Limited threat visibility
- ❌ Fragmented logging

### Solution: OpenWrt Cloud DMZ

OpenWrt provides enterprise features in a lightweight, open-source package:
- ✅ **Zone-based firewall** with granular control
- ✅ **WireGuard VPN** built-in
- ✅ **Intrusion detection** with Suricata
- ✅ **Unified logging** to monitoring stack
- ✅ **Cost-effective** (runs on minimal resources)

### Problem: Loki "Maximum Stream Limit Exceeded"

Many users hit Loki's stream limits due to high-cardinality labels.

**Before (Promtail with high cardinality):**
```
{src_ip="1.2.3.4", dest_port="443", geoip_city="London",
 geoip_lat="51.5081", geoip_long="-0.1278", filename="/var/log/nginx/site1.log"}
= 10,000+ streams → 429 errors
```

**After (Alloy with optimized cardinality):**
```
{job="nginx_logs", host="server01", website="site1"}
= ~20 streams
Query high-cardinality fields with LogQL:
{job="nginx"} | json | src_ip="1.2.3.4" | geoip_city="London"
```

**Result:** 99% fewer streams, no more errors, faster queries!

---

## 🌍 GeoIP Query Examples

All log sources (routers, nginx, Suricata) include GeoIP enrichment for IP addresses. Query geographic data using LogQL:

### Firewall Logs (Routers)

```logql
# All firewall drops from China
{job="oraclewrt_syslog"} | json | geoip_country_name="China"

# Traffic from specific city
{job="openwrt_syslog"} | json | geoip_city_name="Moscow"

# Map attacks by country
{job=~".*_syslog"} | json | geoip_country_name!=""
  | line_format "{{.SRC}} from {{.geoip_city_name}}, {{.geoip_country_name}}"

# SSH attacks from Asia
{job=~".*_syslog"} | json | DPT="22" | geoip_continent_name="Asia"
```

### Web Traffic (Nginx)

```logql
# Visitors from United States
{job="nginx_access"} | json | geoip_country_name="United States"

# 404 errors by country
{job="nginx_access"} | json | status="404" | geoip_country_name!=""

# API requests from Europe
{job="nginx_access", website="api.example.com"}
  | json | geoip_continent_name="Europe"

# Map visitor locations
{job="nginx_access"} | json
  | line_format "{{.remote_addr}} - {{.geoip_city_name}}, {{.geoip_country_name}}"
```

### Security Events (Suricata IDS)

```logql
# Critical alerts from foreign countries
{job="suricata", event_type="alert"}
  | json | severity="1" | geoip_country_name!="United States"

# SQL injection attempts by origin
{job="suricata"} | json | signature=~".*SQL.*"
  | geoip_country_name!=""

# Malware callbacks mapped
{job="suricata"} | json | category="Malware"
  | line_format "{{.dest_ip}} → {{.geoip_city_name}}, {{.geoip_country_name}}"

# DDoS sources by coordinates
{job="suricata", event_type="flow"} | json | geoip_location_latitude!=""
```

### Available GeoIP Fields

All enriched logs include these queryable fields:
- `geoip_country_name` - "United States", "China", "Brazil"
- `geoip_country_code` - "US", "CN", "BR"
- `geoip_city_name` - "New York", "Tokyo", "London"
- `geoip_continent_name` - "North America", "Asia", "Europe"
- `geoip_location_latitude` - "40.7128"
- `geoip_location_longitude` - "-74.0060"

---

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Ways to Contribute
- 🐛 Report bugs or issues
- 💡 Suggest new features or improvements
- 📖 Improve documentation
- 🧪 Test on new cloud providers
- 🎨 Create new Grafana dashboards
- 🔧 Submit bug fixes or enhancements

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Credits

**Created by:** TeckGlobal Development Team

**Based on:** Production deployments monitoring 5+ servers, 38+ Docker containers, handling millions of requests per month.

**Special Thanks to:**
- Grafana Labs for the observability stack
- OpenWrt Project for the incredible router OS
- Suricata Project for IDS/IPS capabilities

---

## ⭐ Star History

If this project helped you, please ⭐ star the repository!

[![Star History Chart](https://api.star-history.com/svg?repos=teckglobal/teckglobal-cloud-dmz-stack&type=Date)](https://star-history.com/#teckglobal/teckglobal-cloud-dmz-stack&Date)

---

## 📞 Support & Community

- **Issues:** [GitHub Issues](https://github.com/teckglobal/teckglobal-cloud-dmz-stack/issues)
- **Discussions:** [GitHub Discussions](https://github.com/teckglobal/teckglobal-cloud-dmz-stack/discussions)
- **Website:** [teck-global.com](https://teck-global.com)

---

**Built with ❤️ by TeckGlobal** | [Website](https://teck-global.com) | [GitHub](https://github.com/teckglobal)
