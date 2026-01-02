# Crossplane v1.15+ Setup Guide

Complete setup guide for the Crossplane Infrastructure Provisioning lab using modern Crossplane v1.15+ API.

## What’s New in v1.15+

**Simplified API** - No separate claims needed:

- Use Composite Resources (XR) directly
- Cleaner developer experience
- Less YAML to maintain
- Same powerful functionality

## Prerequisites

- **Kubernetes cluster** (v1.28+)
- **kubectl** (v1.28+)
- **Helm** (v3.14+)
- **Azure CLI** (latest)
- **jq** (for JSON parsing)

## Quick Start (5 minutes)

```bash
# 1. Install Crossplane
./scripts/install-crossplane.sh

# 2. Configure Azure
./scripts/configure-azure-provider.sh

# 3. Deploy XRDs and Compositions
kubectl apply -f manifests/xrds/
kubectl apply -f manifests/compositions/

# 4. Create your first database (no claim needed!)
kubectl apply -f examples/database-dev.yaml

# 5. Watch it provision
kubectl get xdatabaseinstance -w
```

## Detailed Setup

### 1. Install Crossplane

**Automated**:

```bash
./scripts/install-crossplane.sh
```

**Manual**:

```bash
# Add Helm repo
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  crossplane-stable/crossplane \
  --version 1.15.0 \
  --wait

# Install function (required for modern compositions)
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.2.1
EOF
```

### 2. Configure Azure Provider

**Automated**:

```bash
./scripts/configure-azure-provider.sh
```

This creates:

- Azure service principal
- Kubernetes secrets (azure-secret, db-password)
- Installs Azure provider family

**Manual** (if needed):

```bash
# Create service principal
az ad sp create-for-rbac \
  --name crossplane \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# Create secret
kubectl create secret generic azure-secret \
  -n crossplane-system \
  --from-file=creds=./azure-creds.json

# Install provider
kubectl apply -f manifests/providers/provider-azure.yaml
```

### 3. Deploy XRDs

```bash
# Apply all XRDs
kubectl apply -f manifests/xrds/

# Verify
kubectl get xrd
```

Expected output:

```
NAME                                              ESTABLISHED   OFFERED   AGE
xdatabaseinstances.database.example.com          True          True      30s
xnetworks.network.example.com                    True          True      30s
xstoragebuckets.storage.example.com              True          True      30s
```

### 4. Deploy Compositions

```bash
# Apply all compositions
kubectl apply -f manifests/compositions/

# Verify
kubectl get compositions
```

### 5. Create Infrastructure

**No claims needed!** Use Composite Resources directly:

```bash
# Create dev database
kubectl apply -f examples/database-dev.yaml

# Watch it provision
kubectl get xdatabaseinstance -w
```

Expected flow:

```
NAME                 PROVIDER   SIZE    ENVIRONMENT   READY   ENDPOINT   AGE
app-database-dev    azure      small   dev           False              5s
app-database-dev    azure      small   dev           False              1m
app-database-dev    azure      small   dev           True    psql-...   15m
```

## Using the XRs

### Check Status

```bash
# List all databases
kubectl get xdatabaseinstance

# Detailed status
kubectl describe xdatabaseinstance app-database-dev

# Watch managed resources
kubectl get managed
```

### Access Connection Details

```bash
# Connection secret is created automatically
kubectl get secret app-database-dev-connection

# Decode endpoint
kubectl get secret app-database-dev-connection \
  -o jsonpath='{.data.endpoint}' | base64 -d

# Full connection details
kubectl get secret app-database-dev-connection -o yaml
```

### Update Configuration

```bash
# Change database size
kubectl patch xdatabaseinstance app-database-dev \
  --type merge \
  -p '{"spec":{"parameters":{"size":"medium"}}}'

# Crossplane reconciles the change
kubectl get xdatabaseinstance -w
```

### Delete Resources

```bash
# Delete database
kubectl delete xdatabaseinstance app-database-dev

# Watch cleanup
kubectl get managed -w
```

## Multi-Cloud Example

Same manifest works on different clouds:

```bash
# Deploy to Azure
kubectl apply -f - <<EOF
apiVersion: database.example.com/v1alpha1
kind: XDatabaseInstance
metadata:
  name: test-db-azure
spec:
  parameters:
    cloudProvider: azure
    size: small
    environment: dev
EOF

# Deploy to AWS (change ONE field!)
kubectl apply -f - <<EOF
apiVersion: database.example.com/v1alpha1
kind: XDatabaseInstance
metadata:
  name: test-db-aws
spec:
  parameters:
    cloudProvider: aws  # ← Only change
    size: small
    environment: dev
EOF
```

## Measuring Success

### Time to First Database

```bash
START=$(date +%s)
kubectl apply -f examples/database-dev.yaml
kubectl wait --for=condition=ready xdatabaseinstance/app-database-dev --timeout=30m
END=$(date +%s)
echo "Provisioned in: $((END - START)) seconds"
```

Typical: 15-20 minutes (cloud provider dependent)

### Verify Cloud Portability

```bash
# Create on Azure
kubectl apply -f examples/database-dev.yaml

# Patch to AWS
kubectl patch xdatabaseinstance app-database-dev \
  --type merge \
  -p '{"spec":{"parameters":{"cloudProvider":"aws"}}}'

# Result: Same database, different cloud!
```

## Troubleshooting

### Provider Not Ready

```bash
# Check provider status
kubectl get providers

# View provider logs
kubectl logs -n crossplane-system \
  -l pkg.crossplane.io/provider=upbound-provider-family-azure
```

### Composition Not Working

```bash
# Check if function is installed
kubectl get functions

# Validate composition
./scripts/validate.sh

# Check XR status
kubectl describe xdatabaseinstance <name>
```

### Resources Stuck Deleting

```bash
# Remove finalizers if needed (careful!)
kubectl patch xdatabaseinstance <name> \
  -p '{"metadata":{"finalizers":[]}}' \
  --type=merge
```

## Next Steps

1. **Create Custom Compositions**: Add your own resource types
1. **Implement GitOps**: Use ArgoCD or Flux
1. **Add Monitoring**: Prometheus metrics for Crossplane
1. **Production Hardening**: RBAC, policies, validation

-----

**Version**: 1.0  
**Last Updated**: January 2026
