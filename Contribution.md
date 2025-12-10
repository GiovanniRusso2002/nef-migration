# NEF Helm Chart - File Organization Guide

## Directory Structure Overview

```
nef/
├── Chart.yaml                    # Helm chart metadata
├── values.yaml                   # Configuration values (centralized)
├── README.md                     # Complete project documentation
│
└── templates/
    │
    ├── helpers/                  # Helm template utilities
    │   ├── _deployment.tpl       # Generic deployment template
    │   ├── _helpers.tpl          # Helper functions (names, labels, etc.)
    │   └── _service.tpl          # Generic service template
    │
    ├── services/                 # All microservice definitions
    │   │
    │   ├── nef/                  # Core NEF services (8 services)
    │   │   ├── ue-identity.yaml              # Deployment
    │   │   ├── ue-identity-configmap.yaml    # Configuration
    │   │   ├── ue-identity-service.yaml      # Service
    │   │   │
    │   │   ├── ue-profile.yaml
    │   │   ├── ue-profile-configmap.yaml
    │   │   ├── ue-profile-service.yaml
    │   │   │
    │   │   ├── ue-id.yaml
    │   │   ├── ue-id-configmap.yaml
    │   │   ├── ue-id-service.yaml
    │   │   │
    │   │   ├── ue-address.yaml
    │   │   ├── ue-address-configmap.yaml
    │   │   ├── ue-address-service.yaml
    │   │   │
    │   │   ├── capif.yaml
    │   │   ├── capif-service.yaml
    │   │   │
    │   │   ├── traffic-influence.yaml
    │   │   ├── traffic-influence-configmap.yaml
    │   │   ├── traffic-influence-service.yaml
    │   │   │
    │   │   ├── as-session-with-qos.yaml
    │   │   ├── as-session-with-qos-configmap.yaml
    │   │   ├── as-session-with-qos-service.yaml
    │   │   │
    │   │   ├── dataset-exporter.yaml
    │   │   └── dataset-exporter-service.yaml
    │   │
    │   ├── monitoring/           # Observability & Metrics (4 services)
    │   │   ├── monitoring-event.yaml
    │   │   ├── monitoring-event-configmap.yaml
    │   │   ├── monitoring-event-service.yaml
    │   │   │
    │   │   ├── prometheus.yaml
    │   │   ├── prometheus-configmap.yaml
    │   │   ├── prometheus-rbac.yaml
    │   │   ├── prometheus-service.yaml
    │   │   │
    │   │   ├── grafana.yaml
    │   │   ├── grafana-dashboards-configmap.yaml
    │   │   ├── grafana-datasources-configmap.yaml
    │   │   ├── grafana-dashboard-coresim.yaml
    │   │   └── grafana-service.yaml
    │   │
    │   └── infrastructure/       # Core Infrastructure (3 services)
    │       ├── core-network.yaml
    │       ├── core-network-configmap.yaml
    │       ├── core-network-service.yaml
    │       │
    │       ├── core-simulator.yaml
    │       ├── core-simulator-service.yaml
    │       │
    │       ├── redis-insight.yaml
    │       └── redis-insight-service.yaml
    │
    ├── ingress/                  # API Gateway & Routing
    │   └── ingress-main.yaml     # Nginx Ingress configuration
    │
    └── security/                 # Security & Network Control
        ├── networkpolicies.yaml           # Pod-to-pod communication rules
        ├── poddisruptionbudgets.yaml      # Availability constraints
        └── secrets.yaml                   # Sensitive data (passwords, tokens)
```

## Organizational Philosophy

### 1. **Logical Grouping by Responsibility**

- **services/nef/**: Business logic microservices (UE identity, profile, address management)
- **services/monitoring/**: Observability stack (Prometheus, Grafana, event monitoring)
- **services/infrastructure/**: Core infrastructure (networking, simulation, caching)

### 2. **DRY Principle**

- All configuration centralized in `values.yaml`
- Service endpoints referenced by name: `redis-stack`, `nef-capif`, `nef-core-simulator`
- Template helpers reduce code duplication

### 3. **Consistent Naming Convention**

Each service has three related files:
- `<service>.yaml` - Deployment specification
- `<service>-configmap.yaml` - Configuration data (if needed)
- `<service>-service.yaml` - Kubernetes Service

### 4. **Clear Security Boundary**

- `security/` folder contains all access control policies
- Network policies define allowed communication paths
- Pod disruption budgets ensure availability
- Secrets stored separately for sensitive data

## File Counts by Category

| Category | Files | Purpose |
|----------|-------|---------|
| Helpers | 3 | Template reusability |
| NEF Services | 23 | Core business logic (8 services × 3 files - 1) |
| Monitoring | 13 | Metrics & observability (3 services) |
| Infrastructure | 8 | Core support services (3 services) |
| Ingress | 1 | API routing |
| Security | 3 | Network policies, availability, secrets |
| **Total** | **51** | **Complete platform** |

## Adding New Components

### To Add a New Service

1. **Create files** in appropriate `services/` subdirectory:
   - `services/<category>/<new-service>.yaml` (deployment)
   - `services/<category>/<new-service>-service.yaml` (service)
   - `services/<category>/<new-service>-configmap.yaml` (if needed)

2. **Update values.yaml**:
   ```yaml
   services:
     newService:
       enabled: true
       image: "org/new-service:tag"
   
   newService:
     config:
       enabled: true
       data: |
         key1: value1
   ```

3. **Deploy**:
   ```bash
   helm upgrade nef ./nef
   ```

### To Modify Network Policies

Edit `security/networkpolicies.yaml` to:
- Allow new service communications
- Restrict egress/ingress
- Add namespace isolation

### To Add Monitoring Dashboard

1. Create `services/monitoring/grafana-dashboard-<name>.yaml`
2. Add dashboard JSON to ConfigMap
3. Update `services/monitoring/grafana-dashboards-configmap.yaml` to reference it

## Deployment Workflow

```
1. User customizes values.yaml
        ↓
2. helm lint checks syntax
        ↓
3. Helm templating engine processes:
   - Load helpers (_*.tpl)
   - Generate services from templates
   - Create configmaps, deployments, services
   - Apply network policies and security
        ↓
4. kubectl deploys generated manifests
        ↓
5. Kubernetes reconciles to desired state
   - Creates pods from deployments
   - Sets up services (load balancers)
   - Applies network policies
   - Mounts configmaps
        ↓
6. Services become discoverable via DNS
   (e.g., nef-ue-identity.default.svc.cluster.local)
```



## Validation Commands

```bash
# Validate chart syntax
helm lint ./nef

# Preview generated manifests
helm template nef ./nef

# Dry-run install
helm install nef ./nef --dry-run --debug

# Check deployed resources
kubectl get all -l app.kubernetes.io/instance=nef

# View specific configmap
kubectl get configmap nef-ue-identity-configmap -o yaml
```

## Troubleshooting File Organization

If a service deployment fails after reorganization:

```bash
# 1. Verify file exists in correct location
find ./templates -name "*service-name*"

# 2. Check for typos in values.yaml references
grep -i "service-name" values.yaml

# 3. Lint chart for syntax errors
helm lint ./nef

# 4. Preview generated YAML for the service
helm template nef ./nef | grep -A 20 "kind: Deployment.*service-name"

# 5. Check logs from failed pod
kubectl logs deployment/nef-service-name
```

