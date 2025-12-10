# NEF Helm Chart

[![Helm](https://img.shields.io/badge/Helm-v3-blue)](https://helm.sh/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.25+-blue)](https://kubernetes.io/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

> **Semester Project** - [EURECOM](https://www.eurecom.fr/)
>
> **Supervisor:** Giulio Carota
>
> **Professor:** Adlen Ksentini
>
> **Authors:** Oscar Licciardi & Giovanni Russo

A comprehensive Helm chart for deploying the **Network Exposure Function (NEF)** services on Kubernetes. This chart provides a complete 3GPP-compliant NEF implementation with monitoring, observability, and security features out of the box.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Services](#services)
- [Monitoring](#monitoring)
- [Security](#security)
- [Accessing Services](#accessing-services)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)

## Overview

The NEF Helm chart deploys a modular, microservices-based Network Exposure Function that exposes 3GPP network capabilities to external Application Functions (AFs). The chart includes:

- **NEF API Services**: AS Session with QoS, Traffic Influence, Monitoring Event, UE Identity, UE ID, UE Address, UE Profile
- **Infrastructure Services**: Core Network, Core Simulator, Redis, CAPIF
- **Observability Stack**: Prometheus, Grafana, Dataset Exporter
- **Security Features**: Network Policies, Pod Disruption Budgets, TLS Ingress

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Ingress (NGINX)                                │
│                           nef.local / TLS enabled                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         │                            │                            │
         ▼                            ▼                            ▼
┌─────────────────┐    ┌─────────────────────────┐    ┌─────────────────────┐
│   NEF Services  │    │   Monitoring Stack      │    │   Infrastructure    │
├─────────────────┤    ├─────────────────────────┤    ├─────────────────────┤
│ AS Session QoS  │    │ Prometheus              │    │ Redis Stack         │
│ Traffic Influen │    │ Grafana                 │    │ Redis Insight       │
│ Monitoring Event│    │ Dataset Exporter        │    │ Core Network        │
│ UE Identity     │    │                         │    │ Core Simulator      │
│ UE ID           │    └─────────────────────────┘    │ CAPIF               │
│ UE Address      │                                   └─────────────────────┘
│ UE Profile      │
└─────────────────┘
```

## Prerequisites

Before installing this chart, ensure you have:

- **Kubernetes cluster** (v1.25+)
- **Helm** (v3.x)
- **kubectl** configured for your cluster
- **NGINX Ingress Controller** (optional, for external access)
- **cert-manager** (optional, for automatic TLS certificates)

### Resource Requirements

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| NEF Services | 100m | 128Mi | 500m | 512Mi |
| Core Network | 150m | 256Mi | 1000m | 1Gi |
| Core Simulator | 200m | 256Mi | 1000m | 1Gi |
| Prometheus | 200m | 512Mi | 1000m | 2Gi |
| Grafana | 100m | 256Mi | 500m | 1Gi |
| Redis | 100m | 256Mi | 1000m | 1Gi |

## Quick Start

```bash
# Add Helm repository for dependencies
helm repo add redis-stack https://redis-stack.github.io/helm-redis-stack/
helm repo update

# Install with default configuration
helm install nef ./nef

# Verify installation
kubectl get pods -l app.kubernetes.io/instance=nef

# Port-forward Grafana for local access
kubectl port-forward svc/nef-grafana 3000:3000
```

## Installation

### Basic Installation

```bash
helm install nef ./nef -n nef-system --create-namespace
```

### Installation with Custom Values

```bash
helm install nef ./nef -n nef-system --create-namespace -f custom-values.yaml
```

### Upgrade Existing Installation

```bash
helm upgrade nef ./nef -n nef-system -f custom-values.yaml
```

### Dry Run (Preview Changes)

```bash
helm install nef ./nef --dry-run --debug
```

## Configuration

### Service Toggles

Enable or disable individual services in `values.yaml`:

```yaml
services:
  asSessionWithQos: true    # 3GPP AS Session with QoS API
  trafficInfluence: true    # 3GPP Traffic Influence API
  monitoringEvent: true     # 3GPP Monitoring Event API
  ueIdentity: true          # UE Identity Service
  ueId: true                # UE ID API
  ueAddress: true           # UE Address API
  ueProfile: true           # UE Profile Service
  datasetExporter: true     # Metrics/Dataset Exporter
  coreNetwork: true         # Core Network Service
  coreSimulator: true       # 5G Core Simulator
  capif: true               # CAPIF Service
  redis: true               # Redis Stack
  redisInsight: true        # Redis Insight UI
  prometheus: true          # Prometheus Monitoring
  grafana: true             # Grafana Dashboards
```

### Image Configuration

Override container images:

```yaml
images:
  asSessionWithQos: "openexposure/as-session-with-qos:develop"
  trafficInfluence: "openexposure/traffic-influence:develop"
  monitoringEvent: "openexposure/monitoring-event:develop"
  # ... other images
```

### Core Simulator Configuration

Configure the 5G simulation profile:

```yaml
coreSimulator:
  simulationProfile:
    plmn: { mcc: "001", mnc: "01" }
    dnn: "internet"
    slice: { sst: 1, sd: "FFFFFF" }
    numOfUe: 20          # Number of simulated UEs
    numOfgNB: 10         # Number of simulated gNodeBs
    arrivalRate: 2       # UE arrival rate
```

### QoS Configuration

Define QoS profiles for AS Session with QoS:

```yaml
asSessionWithQos:
  qosConfig:
    qos-e:
      marBwDl: 120000
      marBwUl: 120000
      mediaType: CONTROL
    qos2:
      marBwDl: 240000
      marBwUl: 240000
      mediaType: CONTROL
```

### Ingress Configuration

Configure external access:

```yaml
ingress:
  enabled: true
  className: "nginx"
  hosts:
  - host: nef.local
    paths:
    - path: /3gpp-as-session-with-qos
      pathType: Prefix
      service: nef-as-session-with-qos
      port: 8080
  tls:
  - secretName: nef-tls-cert
    hosts:
    - nef.local
```

### Security Policies

Enable network policies and pod disruption budgets:

```yaml
networkPolicy:
  enabled: true

podDisruptionBudget:
  enabled: true
```

## Services

### NEF API Services

| Service | Port | API Path | Description |
|---------|------|----------|-------------|
| AS Session with QoS | 8080 | `/3gpp-as-session-with-qos` | QoS session management |
| Traffic Influence | 8080 | `/3gpp-traffic-influence` | Traffic routing influence |
| Monitoring Event | 8080 | `/3gpp-monitoring-event` | UE event subscriptions |
| UE ID | 8080 | `/3gpp-ue-id` | UE identifier services |
| UE Address | 8080 | `/3gpp-ue-address` | UE IP address management |

### Infrastructure Services

| Service | Port | Description |
|---------|------|-------------|
| Core Network | 9090 | Core network integration service |
| Core Simulator | 8080/8081 | 5G core network simulator |
| Redis Stack | 6379 | In-memory data store |
| Redis Insight | 5540 | Redis management UI |
| CAPIF | 8080 | Common API Framework |

### Monitoring Services

| Service | Port | Description |
|---------|------|-------------|
| Prometheus | 9090 | Metrics collection and storage |
| Grafana | 3000 | Visualization and dashboards |
| Dataset Exporter | 8080 | Custom metrics exporter |

## Monitoring

### Accessing Grafana

```bash
# Port-forward Grafana
kubectl port-forward svc/nef-grafana 3000:3000

# Access at http://localhost:3000
# Default credentials: admin / (check secret nef-grafana-secret)
```

### Accessing Prometheus

```bash
# Port-forward Prometheus
kubectl port-forward svc/nef-prometheus 9090:9090

# Access at http://localhost:9090
```

### Available Metrics

The chart exposes various metrics including:

- `ue_total` - Total number of UEs
- `pdu_sessions_total` - PDU session count
- `gnb_total` - Number of gNodeBs
- `simulation_*` - Core simulator metrics

### Pre-configured Dashboards

Grafana comes with pre-configured dashboards for:

- Core Simulator Overview
- NEF Services Health
- UE Statistics

## Security

### Network Policies

When enabled, network policies restrict traffic between pods:

- Default deny all ingress traffic
- Explicit allow rules for required communication paths
- Prometheus scraping allowed from monitoring namespace

### TLS/HTTPS

Ingress is configured with:

- TLS 1.2/1.3 only
- Strong cipher suites
- Automatic certificate management (with cert-manager)

### Security Headers

```yaml
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
```

### Rate Limiting

- 100 requests per second
- 50 concurrent connections

## Accessing Services

### Using Port-Forward (Development)

```bash
# Grafana
kubectl port-forward svc/nef-grafana 3000:3000

# Prometheus
kubectl port-forward svc/nef-prometheus 9090:9090

# Core Simulator
kubectl port-forward svc/nef-core-simulator 8081:8080

# Redis Insight
kubectl port-forward svc/nef-redis-insight 5540:5540
```

### Using Ingress (Production)

Add to `/etc/hosts`:
```
<INGRESS_IP> nef.local
```

Access services:
- https://nef.local/grafana
- https://nef.local/prometheus
- https://nef.local/3gpp-as-session-with-qos

### Starting the Simulator

```bash
# Start simulation
curl http://localhost:8081/start

# Check metrics
curl http://localhost:8081/metrics
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l app.kubernetes.io/instance=nef
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Check Service Connectivity

```bash
kubectl get svc -l app.kubernetes.io/instance=nef
kubectl get endpoints <service-name>
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Pods stuck in Pending | Check resource quotas and node capacity |
| ImagePullBackOff | Verify image names and registry access |
| CrashLoopBackOff | Check logs: `kubectl logs <pod>` |
| Service unreachable | Verify NetworkPolicies and service selectors |
| Prometheus targets down | Check scrape configs and network policies |

### Debug Commands

```bash
# Get all resources
kubectl get all -l app.kubernetes.io/instance=nef

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Test DNS resolution
kubectl run -it --rm debug --image=busybox -- nslookup nef-redis

# Check Prometheus targets
curl localhost:9090/api/v1/targets
```

## Uninstallation

```bash
# Uninstall the release
helm uninstall nef -n nef-system

# Delete namespace (optional)
kubectl delete namespace nef-system

# Remove PVCs if needed
kubectl delete pvc -l app.kubernetes.io/instance=nef -n nef-system
```

## Chart Information

| Field | Value |
|-------|-------|
| Chart Version | 0.1.2 |
| App Version | 1.16.0 |
| Type | Application |

## Dependencies

| Dependency | Version | Repository |
|------------|---------|------------|
| redis-stack | 0.4.21 | https://redis-stack.github.io/helm-redis-stack/ |

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Acknowledgments

This project was developed as part of a **Semester Project** at [EURECOM](https://www.eurecom.fr/), Sophia Antipolis, France.

- **Supervisor:** Giulio Carota
- **Professor:** Adlen Ksentini
- **Authors:** Oscar Licciardi & Giovanni Russo

We thank EURECOM and the Communication Systems Department for their support and guidance throughout this project.

## Support

For issues and feature requests, please use the GitHub issue tracker.
