#!/bin/bash
# cleanup.sh
# Cleans up Crossplane resources

set -e

echo "=========================================="
echo "Crossplane Cleanup Script"
echo "=========================================="

# Parse arguments
FULL_CLEANUP=false
if [ "$1" == "--full" ]; then
    FULL_CLEANUP=true
    echo "Full cleanup mode: Will uninstall Crossplane"
else
    echo "Standard cleanup mode: Will delete composite resources"
    echo "Use --full flag to also uninstall Crossplane"
fi

echo ""
read -p "Are you sure you want to proceed? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Delete example resources
echo ""
echo "Deleting example composite resources..."
kubectl delete -f examples/ --ignore-not-found=true

# Wait for resources to be deleted
echo "Waiting for managed resources to be deleted (this may take a few minutes)..."
sleep 10

# Check for remaining managed resources
echo ""
echo "Checking for remaining managed resources..."
if kubectl get managed &> /dev/null; then
    REMAINING=$(kubectl get managed 2>/dev/null | tail -n +2 | wc -l)
    if [ "$REMAINING" -gt 0 ]; then
        echo "Warning: $REMAINING managed resources still exist"
        kubectl get managed
        echo ""
        echo "These will be deleted by Crossplane. Monitor with: kubectl get managed -w"
    fi
fi

# Delete compositions
echo ""
echo "Deleting compositions..."
kubectl delete -f manifests/compositions/ --ignore-not-found=true

# Delete XRDs
echo ""
echo "Deleting XRDs..."
kubectl delete -f manifests/xrds/ --ignore-not-found=true

if [ "$FULL_CLEANUP" = true ]; then
    echo ""
    echo "Deleting providers..."
    kubectl delete -f manifests/providers/ --ignore-not-found=true
    
    echo ""
    echo "Waiting for providers to be deleted..."
    kubectl wait --for=delete provider --all --timeout=180s || echo "Some providers still deleting..."
    
    echo ""
    echo "Deleting function..."
    kubectl delete function.pkg.crossplane.io/function-patch-and-transform --ignore-not-found=true
    
    echo ""
    echo "Uninstalling Crossplane..."
    helm uninstall crossplane -n crossplane-system || echo "Crossplane already uninstalled"
    
    echo ""
    echo "Deleting crossplane-system namespace..."
    kubectl delete namespace crossplane-system --ignore-not-found=true
fi

echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
if [ "$FULL_CLEANUP" = true ]; then
    echo "Crossplane has been fully uninstalled"
else
    echo "Composite resources deleted. Crossplane remains installed."
    echo "To fully uninstall Crossplane, run: $0 --full"
fi
echo ""

