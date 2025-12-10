# Contributing to NEF Helm Chart

> **Semester Project** - [EURECOM](https://www.eurecom.fr/)
>
> **Supervisor:** Giulio Carota | **Professor:** Adlen Ksentini
>
> **Authors:** Oscar Licciardi & Giovanni Russo

Thank you for your interest in contributing to the NEF Helm Chart project! This document provides guidelines and best practices for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Contribution Workflow](#contribution-workflow)
- [Helm Chart Guidelines](#helm-chart-guidelines)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors. We expect everyone to:

- Be respectful and considerate in all interactions
- Welcome newcomers and help them get started
- Accept constructive criticism gracefully
- Focus on what is best for the community and project
- Show empathy towards other community members

### Unacceptable Behavior

- Harassment, discrimination, or offensive comments
- Personal or political attacks
- Publishing others' private information without permission
- Any conduct that would be considered inappropriate in a professional setting

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Git** (v2.x+)
- **Helm** (v3.x+)
- **kubectl** configured with cluster access
- **Docker** (for building custom images)
- A code editor with YAML support (VS Code recommended)

### Fork and Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/<your-username>/nef-migration.git
cd nef-migration

# Add upstream remote
git remote add upstream https://github.com/GiovanniRusso2002/nef-migration.git

# Verify remotes
git remote -v
```

## Development Setup

### Local Kubernetes Cluster

For development, we recommend using:

- **Minikube**: `minikube start --memory=8192 --cpus=4`
- **kind**: `kind create cluster --name nef-dev`
- **Docker Desktop**: Enable Kubernetes in settings

### Install Dependencies

```bash
# Add required Helm repositories
helm repo add redis-stack https://redis-stack.github.io/helm-redis-stack/
helm repo update

# Update chart dependencies
cd nef
helm dependency update
```

### Deploy for Testing

```bash
# Install with development values
helm install nef-dev ./nef --set networkPolicy.enabled=false

# Watch pods come up
kubectl get pods -w

# Clean up
helm uninstall nef-dev
```

## Project Structure

```
nef/
├── Chart.yaml              # Chart metadata and dependencies
├── values.yaml             # Default configuration values
├── README.md               # Chart documentation
├── CONTRIBUTING.md         # This file
├── charts/                 # Dependency charts
└── templates/
    ├── helpers/            # Reusable template helpers
    │   ├── _deployment.tpl # Deployment template helper
    │   ├── _helpers.tpl    # Common helper functions
    │   └── _service.tpl    # Service template helper
    ├── ingress/            # Ingress resources
    │   └── ingress-main.yaml
    ├── security/           # Security-related resources
    │   ├── networkpolicies.yaml
    │   ├── poddisruptionbudgets.yaml
    │   └── secrets.yaml
    └── services/           # Service deployments
        ├── infrastructure/ # Core infrastructure services
        ├── monitoring/     # Observability stack
        └── nef/            # NEF API services
```

## Contribution Workflow

### 1. Create a Branch

```bash
# Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feat/your-feature-name

# Or for bug fixes
git checkout -b fix/issue-description
```

### Branch Naming Convention

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feat/<description>` | `feat/add-health-checks` |
| Bug Fix | `fix/<description>` | `fix/redis-connection` |
| Documentation | `docs/<description>` | `docs/update-readme` |
| Refactor | `refactor/<description>` | `refactor/template-helpers` |
| Chore | `chore/<description>` | `chore/update-dependencies` |

### 2. Make Changes

- Keep changes focused and atomic
- Write clear commit messages
- Test your changes locally

### 3. Commit Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format
<type>(<scope>): <description>

# Examples
feat(services): add health check endpoints
fix(redis): correct connection string format
docs(readme): update installation instructions
refactor(templates): extract common deployment logic
chore(deps): update redis-stack to 0.4.21
```

#### Commit Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code restructuring |
| `test` | Adding tests |
| `chore` | Maintenance tasks |

### 4. Push and Create PR

```bash
git push origin feat/your-feature-name
```

Then create a Pull Request on GitHub.

## Helm Chart Guidelines

### values.yaml Best Practices

```yaml
# Use clear section headers
# =============================================================================
# SECTION NAME
# =============================================================================

# Document all values with comments
serviceName:
  enabled: true       # Enable/disable the service
  replicas: 1         # Number of replicas
  image: "repo/image:tag"  # Container image
```

### Template Guidelines

#### Use Helper Templates

```yaml
# Good - Use helpers for consistency
{{- include "openexposure.labels" (dict "name" "my-service" "context" .) | nindent 4 }}

# Avoid - Duplicating label logic
labels:
  app.kubernetes.io/name: my-service
  app.kubernetes.io/instance: {{ .Release.Name }}
```

#### Conditional Resources

```yaml
# Always check if service is enabled
{{- if .Values.services.myService }}
apiVersion: apps/v1
kind: Deployment
# ...
{{- end }}
```

#### Resource Naming

```yaml
# Use Release.Name prefix for all resources
metadata:
  name: {{ .Release.Name }}-my-service
```

### Security Best Practices

1. **Always run as non-root**:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
```

2. **Define resource limits**:
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

3. **Use NetworkPolicies** for service isolation

4. **Avoid hardcoded secrets** - use Kubernetes Secrets

## Coding Standards

### YAML Style

- Use 2-space indentation
- No trailing whitespace
- Single newline at end of file
- Quote strings that could be interpreted as numbers/booleans

### Helm Templates

- Use `{{-` and `-}}` to control whitespace
- Indent using `nindent` function
- Group related values in `values.yaml`
- Add comments for complex logic

### File Organization

- One resource type per file (generally)
- Group related resources in subdirectories
- Use descriptive filenames: `<service>-<resource>.yaml`

## Testing

### Lint Your Changes

```bash
# Lint the chart
helm lint ./nef

# Check with strict mode
helm lint ./nef --strict
```

### Template Rendering

```bash
# Render templates without installing
helm template nef-test ./nef

# Render with custom values
helm template nef-test ./nef -f custom-values.yaml

# Debug specific template
helm template nef-test ./nef --show-only templates/services/nef/my-service.yaml
```

### Dry Run Installation

```bash
helm install nef-test ./nef --dry-run --debug
```

### Validate Kubernetes Manifests

```bash
# Using kubeval (install separately)
helm template nef-test ./nef | kubeval

# Using kubectl
helm template nef-test ./nef | kubectl apply --dry-run=client -f -
```

### Integration Testing

```bash
# Install and verify
helm install nef-test ./nef --wait --timeout 5m
kubectl get pods -l app.kubernetes.io/instance=nef-test
helm test nef-test

# Clean up
helm uninstall nef-test
```

## Documentation

### Update README.md When:

- Adding new services or features
- Changing configuration options
- Modifying default behavior
- Adding new dependencies

### Document in values.yaml:

```yaml
# Bad - No documentation
myService:
  port: 8080

# Good - Clear documentation
myService:
  # Port the service listens on (must match container port)
  port: 8080
```

### Add Comments in Templates:

```yaml
# Explain complex logic
{{- /*
  Calculate resource limits based on service type.
  Heavier services get more resources.
*/ -}}
```

## Pull Request Process

### Before Submitting

- [ ] Code follows project style guidelines
- [ ] `helm lint` passes without errors
- [ ] Templates render correctly (`helm template`)
- [ ] Changes tested on local cluster
- [ ] Documentation updated if needed
- [ ] Commit messages follow convention

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Documentation update
- [ ] Refactoring
- [ ] Dependency update

## Testing Done
Describe testing performed

## Checklist
- [ ] Helm lint passes
- [ ] Templates render correctly
- [ ] Tested on local cluster
- [ ] Documentation updated
```

### Review Process

1. All PRs require at least one approval
2. CI checks must pass
3. Address reviewer feedback promptly
4. Squash commits before merging (if requested)

## Issue Guidelines

### Bug Reports

Include:
- Helm/Kubernetes version
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs or error messages

### Feature Requests

Include:
- Clear description of the feature
- Use case and motivation
- Proposed implementation (if any)
- Impact on existing functionality

### Issue Labels

| Label | Description |
|-------|-------------|
| `bug` | Something isn't working |
| `enhancement` | New feature request |
| `documentation` | Documentation improvement |
| `good first issue` | Good for newcomers |
| `help wanted` | Extra attention needed |
| `question` | Further information requested |

## Questions?

If you have questions about contributing:

1. Check existing issues and documentation
2. Open a discussion or issue
3. Reach out to maintainers

Thank you for contributing to the NEF Helm Chart project! 🎉
