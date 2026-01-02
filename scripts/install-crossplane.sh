#!/bin/bash
# install-crossplane.sh
# Installs Crossplane v1.15+ with modern configuration

set -e

echo "=========================================="
echo "Installing Crossplane v1.15+"
echo "=========================================="

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "ERROR: helm not found. Please install helm first."
    exit 1
fi

# Crossplane version
CROSSPLANE_VERSION="1.15.0"

# Add Crossplane Helm repository
echo "Adding Crossplane Helm repository..."
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
echo "Installing Crossplane v${CROSSPLANE_VERSION}..."
helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  crossplane-stable/crossplane \
  --version ${CROSSPLANE_VERSION} \
  --wait

echo "Crossplane installed successfully!"

# Wait for Crossplane to be ready
echo "Waiting for Crossplane pods to be ready..."
kubectl wait --for=condition=ready pod \
  -l app=crossplane \
  -n crossplane-system \
  --timeout=300s

# Install Crossplane CLI (optional but recommended)
echo ""
echo "Installing Crossplane CLI..."
curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh
sudo mv crossplane /usr/local/bin/

# Verify CLI installation
crossplane --version

# Install function-patch-and-transform (required for modern compositions)
echo ""
echo "Installing function-patch-and-transform..."
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.2.1
EOF

echo "Waiting for function to be ready..."
sleep 10
kubectl wait --for=condition=healthy function.pkg.crossplane.io/function-patch-and-transform --timeout=300s || echo "Function installation in progress..."

echo ""
echo "=========================================="
echo "Crossplane Installation Complete!"
echo "=========================================="
echo ""
echo "Installed components:"
echo "  - Crossplane ${CROSSPLANE_VERSION}"
echo "  - Crossplane CLI"
echo "  - function-patch-and-transform"
echo ""
echo "Next steps:"
echo "1. Configure cloud provider: ./scripts/configure-azure-provider.sh"
echo "2. Deploy XRDs: kubectl apply -f manifests/xrds/"
echo "3. Deploy compositions: kubectl apply -f manifests/compositions/"
echo "4. Create infrastructure: kubectl apply -f examples/"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n crossplane-system"
echo "  kubectl get providers"
echo "  kubectl get functions"
echo "  kubectl get xrd"
echo "  kubectl get compositions"
echo ""

