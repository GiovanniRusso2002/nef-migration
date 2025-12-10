# NEF (Network Exposure Function) Helm Chart

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Configuration Management](#configuration-management)
4. [Services](#services)
5. [Installation](#installation)
6. [Configuration](#configuration)
7. [Network Policies](#network-policies)
8. [Monitoring and Observability](#monitoring-and-observability)
9. [Troubleshooting](#troubleshooting)

---

## Overview

This Helm chart deploys a complete NEF (Network Exposure Function) microservices platform on Kubernetes. The platform provides network service exposure and API management capabilities with integrated monitoring, security, and state management.

**Chart Details:**
- Helm version: 3.x
- Kubernetes version: 1.19+
- Default namespace: default
- Services deployed: 14 microservices
- ConfigMaps: 13 (centrally managed)

**Key Characteristics:**
- DRY (Don't Repeat Yourself) configuration principles throughout
- Centralized service discovery via Kubernetes DNS
- Automatic ConfigMap generation from templated values
- Network policies for service-to-service security
- Complete observability stack (Prometheus + Grafana)
- Data persistence via Redis Stack

---

## Architecture

### System Design

The NEF platform follows a microservices architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────────┐
│                         Ingress Controller                        │
│                      (nginx-ingress)                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
    ┌───▼────┐         ┌─────▼────┐         ┌────▼──┐
    │  CAPIF │         │   NEF    │         │Ingress│
    │ (Core  │         │ Services │         │Config │
    │ API    │         │          │         │       │
    │Policy) │         │          │         │       │
    └────┬───┘         └─────┬────┘         └───────┘
         │                   │
         └───────┬───────────┘
                 │
    ┌────────────▼──────────────────────────────┐
    │      NEF Service Layer                     │
    │  ┌──────────────────────────────────────┐ │
    │  │  UE Services                          │ │
    │  │ - ue-identity                         │ │
    │  │ - ue-profile                          │ │
    │  │ - ue-id                               │ │
    │  │ - ue-address                          │ │
    │  └──────────────────────────────────────┘ │
    │  ┌──────────────────────────────────────┐ │
    │  │  Network Services                     │ │
    │  │ - traffic-influence                   │ │
    │  │ - as-session-with-qos                 │ │
    │  │ - dataset-exporter                    │ │
    │  └──────────────────────────────────────┘ │
    │  ┌──────────────────────────────────────┐ │
    │  │  Core Services                        │ │
    │  │ - core-network                        │ │
    │  │ - core-simulator                      │ │
    │  │ - monitoring-event                    │ │
    │  └──────────────────────────────────────┘ │
    └────────────────┬───────────────────────────┘
                     │
    ┌────────────────┼──────────────────────────┐
    │                │                          │
┌───▼──────┐    ┌────▼────────┐        ┌──────▼────┐
│  Redis   │    │   CoreSim    │        │ Prometheus│
│ (Cache)  │    │ (Simulator)  │        │           │
└──────────┘    └──────────────┘        └─────┬─────┘
                                               │
                                          ┌────▼─────┐
                                          │  Grafana  │
                                          │ Dashboard │
                                          └───────────┘
```

### Service Communication Flow

1. **External Traffic**: Enters via Ingress Controller with TLS termination
2. **API Gateway**: Routed through CAPIF for policy enforcement
3. **NEF Services**: Process requests according to configuration
4. **State Management**: Redis Stack handles caching and state
5. **Core Simulation**: Core-network communicates with core-simulator for testing
6. **Monitoring**: All services emit metrics to Prometheus
7. **Visualization**: Grafana displays real-time dashboards

### Network Policies

- Pod-to-pod communication is explicitly allowed via Kubernetes NetworkPolicies
- Service-to-service communication uses Kubernetes DNS service discovery
- External ingress restricted to specific ports (HTTP/HTTPS)
- Egress policies control outbound traffic from pods

---

## Configuration Management

### DRY Principle Implementation

All configuration values are centralized in `values.yaml` to eliminate duplication and ensure consistency:

```yaml
# Central service references
redis:
  address: "redis-stack:6379"
  uri: "redis://redis-stack:6379/"

capif:
  address: "nef-capif:8080"

# Service configurations
services:
  ueIdentity:
    enabled: true
    image: "openexposure/ue-identity-service:develop"
    port: 8080
    
ueIdentity:
  config:
    enabled: true
    data: |
      httpVersion: 1.1
      ...
```

### ConfigMap Strategy

**ConfigMaps are created for:**
- ue-identity
- ue-profile
- ue-id
- ue-address
- core-network
- as-session-with-qos
- traffic-influence
- monitoring-event
- prometheus
- grafana-dashboards
- grafana-datasources

**Configuration Format:**
- YAML ConfigMaps with environment-variable style keys
- Mounted at `/etc/config.yaml` in respective pods
- Passed as environment variables for legacy services (core-network)

**Template Pattern:**
```yaml
{{- if and .Values.services.<service> .Values.<service>.config.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "openexposure.fullname" . }}-<service>-configmap
  labels:
    {{- include "openexposure.labels" . | nindent 4 }}
data:
  config.yaml: |
    {{ .Values.<service>.config.data | nindent 4 }}
{{- end }}
```

### Service Integration Points

**Redis Stack** (`redis-stack:6379`):
- Centralized cache for all services
- Connection: `redis-stack:6379` (address) or `redis://redis-stack:6379/` (URI)
- Used by: ue-identity, ue-profile, ue-id, ue-address, monitoring-event

**CAPIF Service** (`nef-capif:8080`):
- Core API Policy Framework
- Connection: `nef-capif:8080`
- Used by: ue-id, ue-address, monitoring-event, as-session-with-qos

**Core Simulator** (`nef-core-simulator:8081`):
- Simulates core network events
- Connection: `nef-core-simulator:8081`
- Used by: core-network for AMF/SMF subscriptions

---

## Services

### UE Services Cluster

These services handle UE (User Equipment) related operations:

#### 1. UE Identity Service (`ue-identity`)
- **Port**: 8080
- **Purpose**: UE identity authentication and management
- **Configuration Key**: `ueIdentity.config`
- **Dependencies**: Redis (caching)
- **ConfigMap**: `nef-ue-identity-configmap`
- **Key Configuration**:
  ```yaml
  httpVersion: 1.1
  redisAddress: redis-stack:6379
  redisPort: 6379
  httpPort: 8080
  nbiPort: 5566
  httpsFlag: false
  ```

#### 2. UE Profile Service (`ue-profile`)
- **Port**: 8080
- **Purpose**: UE profile data storage and retrieval
- **Configuration Key**: `ueProfile.config`
- **Dependencies**: Redis
- **ConfigMap**: `nef-ue-profile-configmap`
- **Key Configuration**:
  ```yaml
  httpVersion: 1.1
  redisAddress: redis-stack:6379
  nbiPort: 5568
  httpsFlag: false
  ```

#### 3. UE ID Service (`ue-id`)
- **Port**: 8080
- **Purpose**: UE identifier management and mapping
- **Configuration Key**: `ueId.config`
- **Dependencies**: UE Identity, CAPIF
- **ConfigMap**: `nef-ue-id-configmap`
- **Key Configuration**:
  ```yaml
  nbiId: nef-ue-id
  nbiIp: 0.0.0.0
  nbiPort: 5570
  nbiUri: /nuniprotocol/v1/ue-address-info/
  sbiId: nef-ue-id
  sbiIp: 0.0.0.0
  sbiPort: 5571
  sbiUri: /nuniprotocol/v1/ue-address-info/
  identitySvc: http://nef-ue-identity:8080
  capifSvc: nef-capif:8080
  ```

#### 4. UE Address Service (`ue-address`)
- **Port**: 8080
- **Purpose**: UE address resolution and location tracking
- **Configuration Key**: `ueAddress.config`
- **Dependencies**: UE Identity, UE Profile, CAPIF
- **ConfigMap**: `nef-ue-address-configmap`
- **Key Configuration**:
  ```yaml
  nbiId: nef-ue-address
  nbiPort: 5572
  sbiPort: 5573
  identitySvc: http://nef-ue-identity:8080
  profileSvc: http://nef-ue-profile:8080
  capifSvc: nef-capif:8080
  ```

### Network Services Cluster

#### 5. Traffic Influence Service (`traffic-influence`)
- **Port**: 8080
- **Purpose**: Dynamic traffic shaping and QoS management
- **ConfigMap**: `nef-traffic-influence-configmap`
- **Dependencies**: CAPIF, Redis

#### 6. AS Session with QoS Service (`as-session-with-qos`)
- **Port**: 8080
- **Purpose**: Application Server session management with Quality of Service
- **ConfigMap**: `nef-as-session-with-qos-configmap`
- **Dependencies**: CAPIF

#### 7. Dataset Exporter (`dataset-exporter`)
- **Port**: 8080
- **Purpose**: Export and manage network datasets
- **No ConfigMap** (lightweight service)

#### 8. CAPIF Service (`capif`)
- **Port**: 8080
- **Purpose**: Core API Policy Framework - centralized policy management
- **No ConfigMap** (core infrastructure service)

### Core Services Cluster

#### 9. Core Network Service (`core-network`)
- **Port**: 8080 (service), 9090 (metrics)
- **Purpose**: Core network event handling and subscriptions
- **ConfigMap**: `nef-core-network-configmap`
- **Configuration Delivery**: Environment variables (not file-based)
- **Key Configuration**:
  ```yaml
  amfIpAddr: http://nef-core-simulator:8081
  smfIpAddr: http://nef-core-simulator:8081
  redisAddress: redis-stack:6379
  ```
- **Special Note**: Service expects environment variables rather than config file

#### 10. Core Simulator (`core-simulator`)
- **Port**: 8081
- **Purpose**: Simulates 5G core network elements (AMF/SMF)
- **No ConfigMap** (pre-configured simulation engine)
- **Provides**: Event subscription endpoints for testing

#### 11. Monitoring Event Service (`monitoring-event`)
- **Port**: 8080
- **Purpose**: Event monitoring and exposure
- **ConfigMap**: `nef-monitoring-event-configmap`
- **Dependencies**: UE Identity, Redis, CAPIF
- **Key Configuration**:
  ```yaml
  redisSvc: redis://redis-stack:6379/
  identitySvc: http://nef-ue-identity:8080
  capifSvc: nef-capif:8080
  ```

### Infrastructure & Observability Services

#### 12. Redis Stack (`redis-stack`)
- **Port**: 6379
- **Purpose**: Distributed caching and state management
- **Provides**: Central data store for all services
- **Type**: StatefulSet (persistent storage)

#### 13. Prometheus (`prometheus`)
- **Port**: 9090
- **Purpose**: Metrics collection and time-series database
- **ConfigMap**: `nef-prometheus-configmap`
- **Scrape Targets**: All services exporting metrics
- **Retention**: Configurable via values.yaml

#### 14. Grafana (`grafana`)
- **Port**: 3000
- **Purpose**: Metrics visualization and dashboards
- **ConfigMaps**: 
  - `nef-grafana-dashboards-configmap`
  - `nef-grafana-datasources-configmap`
- **Default Dashboards**: CoreSimulator monitoring dashboard
- **Data Source**: Prometheus

**Additional Infrastructure:**

#### Redis Insight (`redis-insight`)
- **Port**: 8001
- **Purpose**: Redis GUI and management tool
- **Access**: Via Ingress or port-forward

---

## Installation

### Prerequisites

- Kubernetes cluster v1.19 or later
- Helm 3.x installed
- kubectl configured to access cluster
- At least 8GB available memory in cluster
- 50GB available storage for Redis and Prometheus

### Installation Steps

**1. Add Helm Repository** (if using remote repo):
```bash
helm repo add openexposure <repository-url>
helm repo update
```

**2. Install Chart**:
```bash
# Install in default namespace
helm install nef ./nef

# Or in specific namespace
helm install nef ./nef -n <namespace> --create-namespace

# With custom values
helm install nef ./nef -f custom-values.yaml
```

**3. Verify Installation**:
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/instance=nef

# Check ConfigMaps created
kubectl get configmaps -l app.kubernetes.io/instance=nef

# Check services
kubectl get svc -l app.kubernetes.io/instance=nef
```

**4. Access Services**:

```bash
# Grafana Dashboard
kubectl port-forward svc/nef-grafana 3000:3000
# Access: http://localhost:3000

# Prometheus
kubectl port-forward svc/nef-prometheus 9090:9090
# Access: http://localhost:9090

# Redis Insight
kubectl port-forward svc/nef-redis-insight 8001:8001
# Access: http://localhost:8001

# Core-Network Service
kubectl port-forward svc/nef-core-network 8080:8080
# Access: http://localhost:8080
```

### Uninstall

```bash
helm uninstall nef

# Or in specific namespace
helm uninstall nef -n <namespace>
```

---

## Configuration

### Modifying values.yaml

All configurable parameters are in `values.yaml`. Key sections:

**1. Global Settings**:
```yaml
nameOverride: ""
fullnameOverride: ""
replicaCount: 1  # Replicas for deployments
```

**2. Service Enable/Disable**:
```yaml
services:
  ueIdentity:
    enabled: true
  ueProfile:
    enabled: true
  # ... etc
```

**3. Image Repository & Tags**:
```yaml
image:
  repository: openexposure
  tag: develop
  pullPolicy: IfNotPresent
```

**4. Resource Limits**:
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

**5. Service Configuration**:
```yaml
ueIdentity:
  config:
    enabled: true
    data: |
      httpVersion: 1.1
      redisAddress: {{ .Values.redis.address }}
      # ... service-specific config
```

### Updating Configuration

**To update a specific service configuration**:

```bash
# Edit values.yaml
vim values.yaml

# Upgrade release
helm upgrade nef ./nef

# Verify new ConfigMaps
kubectl get configmap nef-<service>-configmap -o yaml
```

### Adding New Services

**To add a new service**:

1. Add deployment template in `templates/services/nef/<service>.yaml`
2. Add service template in `templates/services/nef/<service>-service.yaml`
3. Create ConfigMap template (if needed) in `templates/services/nef/<service>-configmap.yaml`
4. Add values section in `values.yaml`:
   ```yaml
   <service>:
     config:
       enabled: true
       data: |
         key1: value1
         key2: value2
   ```
5. Update `services.<service>.enabled: true` in values.yaml
6. Run `helm upgrade nef ./nef`

---

## Network Policies

### Overview

Network policies control pod-to-pod and pod-to-external communication. The chart includes predefined policies for:

1. **Ingress Rules**: External traffic to service ports
2. **Egress Rules**: Service-to-service and external connectivity

### Default Policies

**Location**: `templates/security/networkpolicies.yaml`

**Allowed Communications**:
- Ingress Controller → NEF Services (ports 8080, 3000, 9090, etc.)
- NEF Services → Redis Stack (port 6379)
- NEF Services → CAPIF (port 8080)
- Core-Network → Core Simulator (port 8081)
- Services → Prometheus (port 9090 metrics)
- Services → kube-dns (port 53 for DNS)

**Restricted Communications**:
- Cross-namespace communication (unless explicitly allowed)
- Direct pod-to-pod without policy
- Unexpected egress ports

### Modifying Network Policies

Edit `templates/security/networkpolicies.yaml` to:
- Add new service communication routes
- Restrict specific pod communications
- Enable/disable namespace isolation

### Pod Disruption Budgets

Location: `templates/security/poddisruptionbudgets.yaml`

PDBs prevent accidental simultaneous pod evictions during cluster maintenance. Current settings:
- `minAvailable: 1` for each service

---

## Monitoring and Observability

### Prometheus Metrics

**Collection Points**:
- All service pods export metrics on port 9090/metrics
- Prometheus scrapes every 30 seconds (configurable)
- Metrics retained for 30 days (configurable)

**ConfigMap Location**: `templates/services/monitoring/prometheus-configmap.yaml`

**Scrape Configuration**:
```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 30s

scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

### Grafana Dashboards

**Default Dashboards**:
1. **CoreSimulator Dashboard** - Monitors core-simulator events and subscriptions
2. **Service Health** - Pod status, resource usage, restarts
3. **Network Metrics** - Traffic flow, message rates
4. **Redis Performance** - Cache hits/misses, memory usage

**ConfigMap Locations**:
- Dashboard definitions: `templates/services/monitoring/grafana-dashboard-coresim.yaml`
- DataSource config: `templates/services/monitoring/grafana-datasources-configmap.yaml`
- Dashboard provisioning: `templates/services/monitoring/grafana-dashboards-configmap.yaml`

**Adding Custom Dashboards**:

1. Export dashboard JSON from Grafana (UI)
2. Create new ConfigMap in `templates/services/monitoring/`:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: nef-grafana-dashboard-custom
     labels:
       grafana_dashboard: "1"
   data:
     custom-dashboard.json: |
       { "dashboard": { ... } }
   ```
3. Update values.yaml with dashboard data
4. Reapply chart: `helm upgrade nef ./nef`

### Service Logging

**Log Locations**:
```bash
# View pod logs
kubectl logs -f deployment/nef-ue-identity

# View multiple pods
kubectl logs -f -l app.kubernetes.io/name=nef

# Previous pod logs (if crashed)
kubectl logs <pod-name> --previous
```

**Log Levels**: Configurable via service environment variables

---

## Troubleshooting

### Common Issues

**1. ConfigMap Nil Pointer Errors**
```
Error: template: openexposure/templates/...: error calling include: 
template: openexposure/templates/...: nil pointer evaluating interface {}.data
```

**Cause**: Missing `config.enabled: true` in values.yaml for a service

**Solution**:
```bash
# Check values.yaml for service config section
grep -A 5 "<service>:" values.yaml

# Ensure format:
# <service>:
#   config:
#     enabled: true
#     data: |
#       key: value
```

**2. Pod Crash with Connection Refused**
```
Error: dial tcp [::1]:8080: connect: connection refused
```

**Cause**: Service trying to connect to localhost instead of service DNS name

**Solution**:
- Check service configmap for correct endpoint
- Verify ConfigMap is mounted: `kubectl describe pod <pod-name>`
- Check if service is running: `kubectl get svc`

**3. Grafana Secret Not Found**
```
Error: couldn't find key grafana-admin-password in Secret default/nef-secrets
```

**Cause**: Grafana attempting to load credentials from missing secret

**Solution**:
- Check if `secrets.yaml` is deployed
- Verify secret exists: `kubectl get secrets nef-secrets`
- Recreate: `helm upgrade --force nef ./nef`

**4. Core-Network Connection to Core-Simulator**
```
Error: Post 'http://localhost:8080/namf-evts/v1/subscriptions': connection refused
```

**Cause**: Service not configured with correct simulator endpoint

**Solution**:
```bash
# Verify core-simulator is running
kubectl get pod -l app.kubernetes.io/name=nef-core-simulator

# Check port: should be 8081 not 8080
kubectl get svc nef-core-simulator

# Verify environment variables in core-network
kubectl env pod <core-network-pod> | grep -i amf
# Should show: AMF_IP_ADDR=http://nef-core-simulator:8081
```

**5. Redis Connection Failures**
```
Error: Connection to redis-stack:6379 timed out
```

**Cause**: Redis service not running or network policy blocking

**Solution**:
```bash
# Check Redis pod
kubectl get pod -l app.kubernetes.io/name=redis-stack

# Test connectivity from service pod
kubectl exec -it <service-pod> -- redis-cli -h redis-stack ping
# Should return: PONG

# Check network policies
kubectl get networkpolicy
kubectl describe networkpolicy <policy-name>
```

**6. DNS Resolution Issues**
```
Error: lookup redis-stack: no such host
```

**Cause**: DNS not resolving Kubernetes service names

**Solution**:
```bash
# Check DNS pod
kubectl get pod -n kube-system -l k8s-app=kube-dns

# Test DNS from pod
kubectl run -it --rm debug --image=busybox -- nslookup redis-stack
# Should return IP address

# Check CoreDNS logs if failing
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### Debugging Commands

```bash
# Check all resources created by chart
kubectl get all -l app.kubernetes.io/instance=nef

# Check ConfigMap content
kubectl get configmap <name> -o yaml

# Check service endpoints
kubectl get endpoints <service-name>

# Check pod events
kubectl describe pod <pod-name>

# Stream logs in real-time
kubectl logs -f <pod-name>

# Check inter-pod connectivity
kubectl exec <pod> -- curl http://<service>:8080/health

# Check system events
kubectl get events --sort-by='.lastTimestamp'

# Validate chart syntax before install
helm lint ./nef

# Dry-run install to see generated manifests
helm install nef ./nef --dry-run --debug

# Check resource usage
kubectl top nodes
kubectl top pods
```

### Health Checks

**Service Liveness**:
```bash
# Check if service is responding
for svc in nef-ue-identity nef-ue-profile nef-core-network; do
  echo "Testing $svc..."
  kubectl exec -it deployment/$svc -- curl -s http://localhost:8080/health || echo "FAILED"
done
```

**ConfigMap Validation**:
```bash
# List all ConfigMaps
kubectl get configmap | grep nef

# Expected count: 13
kubectl get configmap -l app.kubernetes.io/instance=nef | wc -l

# Verify specific ConfigMap content
kubectl get configmap nef-<service>-configmap -o jsonpath='{.data.config\.yaml}' | head -20
```

**Network Connectivity**:
```bash
# Test pod-to-pod communication
kubectl exec <pod1> -- curl -v http://<pod2-service>:8080

# Test DNS from pod
kubectl exec <pod> -- nslookup redis-stack
kubectl exec <pod> -- nslookup nef-capif

# Check network policies in effect
kubectl get networkpolicy
kubectl describe networkpolicy nef-network-policy
```

### Performance Monitoring

**Resource Usage**:
```bash
# Real-time resource monitoring
kubectl top pods -l app.kubernetes.io/instance=nef

# Pod memory/CPU trends via Prometheus query
# In Grafana: sum(container_memory_usage_bytes) by (pod_name)
```

**Service Latency**:
View in Grafana dashboard or query Prometheus:
```
http_request_duration_seconds
```

**Error Rates**:
```
rate(http_requests_total{status=~"5.."}[5m])
```

---

## Directory Structure

```
nef/
├── Chart.yaml                          # Chart metadata
├── values.yaml                         # Default configuration values
├── README.md                           # This file
└── templates/
    ├── helpers/
    │   ├── _deployment.tpl             # Generic deployment template
    │   ├── _helpers.tpl                # Helm helper functions
    │   └── _service.tpl                # Generic service template
    ├── services/
    │   ├── nef/                        # Core NEF services
    │   │   ├── ue-identity.yaml        # Deployment
    │   │   ├── ue-identity-configmap.yaml
    │   │   ├── ue-identity-service.yaml
    │   │   ├── ue-profile.yaml
    │   │   ├── ue-profile-configmap.yaml
    │   │   ├── ue-profile-service.yaml
    │   │   ├── ue-id.yaml
    │   │   ├── ue-id-configmap.yaml
    │   │   ├── ue-id-service.yaml
    │   │   ├── ue-address.yaml
    │   │   ├── ue-address-configmap.yaml
    │   │   ├── ue-address-service.yaml
    │   │   ├── capif.yaml
    │   │   ├── capif-service.yaml
    │   │   ├── traffic-influence.yaml
    │   │   ├── traffic-influence-configmap.yaml
    │   │   ├── traffic-influence-service.yaml
    │   │   ├── as-session-with-qos.yaml
    │   │   ├── as-session-with-qos-configmap.yaml
    │   │   ├── as-session-with-qos-service.yaml
    │   │   ├── dataset-exporter.yaml
    │   │   └── dataset-exporter-service.yaml
    │   ├── monitoring/                 # Observability services
    │   │   ├── monitoring-event.yaml
    │   │   ├── monitoring-event-configmap.yaml
    │   │   ├── monitoring-event-service.yaml
    │   │   ├── prometheus.yaml
    │   │   ├── prometheus-configmap.yaml
    │   │   ├── prometheus-rbac.yaml
    │   │   ├── prometheus-service.yaml
    │   │   ├── grafana.yaml
    │   │   ├── grafana-dashboards-configmap.yaml
    │   │   ├── grafana-datasources-configmap.yaml
    │   │   ├── grafana-dashboard-coresim.yaml
    │   │   └── grafana-service.yaml
    │   └── infrastructure/             # Core infrastructure
    │       ├── core-network.yaml
    │       ├── core-network-configmap.yaml
    │       ├── core-network-service.yaml
    │       ├── core-simulator.yaml
    │       ├── core-simulator-service.yaml
    │       ├── redis-insight.yaml
    │       └── redis-insight-service.yaml
    ├── ingress/
    │   └── ingress-main.yaml           # Ingress configuration
    └── security/
        ├── networkpolicies.yaml        # Network policies
        ├── poddisruptionbudgets.yaml   # PDB constraints
        └── secrets.yaml                # Sensitive configuration

```

--

For questions or issues, refer to the Troubleshooting section or consult the service-specific configuration details above.
