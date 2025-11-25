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

```
                                    Internet
                                       │
                                       ▼
                            ┌──────────────────┐
                            │   Cloud Provider │
                            │   Public IP/VIP  │
                            └────────┬─────────┘
                                     │
                         ┌───────────▼──────────┐
                         │    OpenWrt Router    │
                         │   (DMZ Gateway)      │
                         │  ┌────────────────┐  │
                         │  │ WireGuard VPN  │  │
                         │  │ Suricata IDS   │  │
                         │  │ Firewall/NAT   │  │
                         │  │ DNS over TLS   │  │
                         │  └────────────────┘  │
                         └───────┬──────────────┘
                                 │
                    ┌────────────┼────────────┐
                    │                         │
         ┌──────────▼─────────┐    ┌─────────▼──────────┐
         │   Monitoring Hub   │    │   Application      │
         │   (Oracle01)       │    │   Server           │
         │                    │    │   (Oracle02)       │
         │  • Grafana         │    │                    │
         │  • Loki            │    │  • Nginx           │
         │  • Mimir           │    │  • Docker Apps     │
         │  • Alloy           │    │  • Databases       │
         │  • Prometheus      │    │  • Alloy Agent     │
         └────────────────────┘    └────────────────────┘
                    │
         ┌──────────▼─────────┐
         │   Remote Site      │
         │   (Home/Office)    │
         │                    │
         │  • Local OpenWrt   │
         │  • WireGuard VPN   │
         │  • Local Servers   │
         └────────────────────┘
```

### Data Flow

**Logs:**
```
OpenWrt → Promtail → Loki (syslog, firewall logs)
Servers → Alloy    → Loki (app logs, system logs)
```

**Metrics:**
```
Servers       → Alloy         → Mimir
Docker        → cAdvisor      → Alloy → Mimir
node_exporter → Prometheus    → Alloy → Mimir
```

**Security Events:**
```
Network Traffic → Suricata → Promtail → Loki
                           ↓
                     eve.json (JSON logs)
                           ↓
                  GeoIP + Threat Analysis
```

---

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Cloud VM with:
  - 4GB+ RAM (monitoring hub)
  - 2GB+ RAM (application servers)
  - Ubuntu 22.04+ or Debian 11+
- (Optional) OpenWrt VM for DMZ gateway

### Single Server Deployment

```bash
# Clone the repository
git clone https://github.com/teckglobal/teckglobal-cloud-dmz-stack
cd teckglobal-cloud-dmz-stack/examples/single-server

# Copy and configure environment
cp .env.example .env
nano .env  # Edit your settings

# Deploy the stack
docker-compose up -d

# Verify deployment
docker-compose ps
```

**Access:**
- Grafana: http://your-server:3000 (admin/admin)
- Loki: http://your-server:3100
- Alloy UI: http://your-server:12345

### Multi-Server Deployment

See [examples/multi-server/README.md](examples/multi-server/README.md)

---

## 💡 Use Cases

### 1. **Cloud DMZ Gateway**
Deploy OpenWrt as a virtual router in your cloud VPC to control all traffic ingress/egress with enterprise firewall capabilities.

### 2. **Site-to-Site VPN**
Connect multiple cloud regions or connect cloud infrastructure to on-premises networks with WireGuard VPN.

### 3. **Security Monitoring**
Monitor all network traffic with Suricata IDS, analyze threats with GeoIP, and visualize in Grafana dashboards.

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
- [Architecture Overview](docs/ARCHITECTURE.md)
- [Configuration Guide](docs/CONFIGURATION.md)

### OpenWrt DMZ
- [OpenWrt VM Setup](docs/openwrt/OPENWRT-VM-SETUP.md)
- [Cloud Provider Guides](docs/openwrt/CLOUD-PROVIDERS.md)
- [WireGuard Configuration](docs/openwrt/WIREGUARD-SETUP.md)
- [Firewall Best Practices](docs/openwrt/FIREWALL-CONFIG.md)

### Monitoring
- [Migration from Promtail to Alloy](docs/monitoring/MIGRATION-FROM-PROMTAIL.md)
- [Loki Cardinality Guide](docs/monitoring/CARDINALITY-GUIDE.md)
- [Dashboard Guide](docs/monitoring/DASHBOARDS.md)
- [Alert Configuration](docs/monitoring/ALERTS.md)

### Security
- [Suricata IDS Setup](docs/security/SURICATA-SETUP.md)
- [Security Hardening](docs/security/HARDENING.md)
- [Threat Analysis](docs/security/THREAT-ANALYSIS.md)

### Troubleshooting
- [Common Issues](docs/TROUBLESHOOTING.md)
- [Performance Tuning](docs/PERFORMANCE.md)

---

## ☁️ Cloud Provider Guides

We provide step-by-step guides for deploying OpenWrt DMZ gateways on major cloud providers:

- **[Oracle Cloud (OCI)](docs/cloud-providers/OCI.md)** - ✅ Tested & Verified
- **[AWS](docs/cloud-providers/AWS.md)** - ✅ Tested & Verified
- **[Azure](docs/cloud-providers/AZURE.md)** - 🚧 In Progress
- **[Google Cloud (GCP)](docs/cloud-providers/GCP.md)** - 🚧 In Progress
- **[DigitalOcean](docs/cloud-providers/DIGITALOCEAN.md)** - 📋 Planned
- **[Linode](docs/cloud-providers/LINODE.md)** - 📋 Planned

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
