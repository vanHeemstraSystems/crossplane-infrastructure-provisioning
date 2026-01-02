#!/bin/bash
# configure-azure-provider.sh
# Configures Azure provider for Crossplane v1.15+

set -e

echo "=========================================="
echo "Configuring Azure Provider for Crossplane"
echo "=========================================="

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    echo "ERROR: Azure CLI not found. Please install Azure CLI first."
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo "ERROR: Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Using Azure Subscription: $SUBSCRIPTION_ID"

# Create service principal for Crossplane
echo ""
echo "Creating Azure service principal for Crossplane..."
SP_NAME="crossplane-sp-$(date +%s)"

SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role Contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --query "{clientId: appId, clientSecret: password, tenantId: tenant}" \
  -o json)

CLIENT_ID=$(echo $SP_OUTPUT | jq -r .clientId)
CLIENT_SECRET=$(echo $SP_OUTPUT | jq -r .clientSecret)
TENANT_ID=$(echo $SP_OUTPUT | jq -r .tenantId)

echo "Service Principal created:"
echo "  Client ID: $CLIENT_ID"
echo "  Tenant ID: $TENANT_ID"
echo "  (Client Secret stored securely)"

# Create Azure credentials file
echo ""
echo "Creating Azure credentials file..."
cat > azure-credentials.json <<EOF
{
  "clientId": "$CLIENT_ID",
  "clientSecret": "$CLIENT_SECRET",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT_ID",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
EOF

# Create database password secret
echo ""
echo "Creating database password secret..."
DB_PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic db-password \
  -n crossplane-system \
  --from-literal=password="$DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Kubernetes secret
echo "Creating Kubernetes secret for Azure credentials..."
kubectl create secret generic azure-secret \
  -n crossplane-system \
  --from-file=creds=./azure-credentials.json \
  --dry-run=client -o yaml | kubectl apply -f -

# Clean up credentials file
rm azure-credentials.json
echo "Credentials file cleaned up for security"

# Install Azure provider
echo ""
echo "Installing Azure provider family..."
kubectl apply -f manifests/providers/provider-azure.yaml

# Wait for provider to be installed
echo "Waiting for provider to be ready (this may take 2-3 minutes)..."
sleep 30

kubectl wait --for=condition=healthy provider.pkg.crossplane.io/upbound-provider-family-azure --timeout=300s || echo "Provider installation in progress..."

echo ""
echo "=========================================="
echo "Azure Provider Configuration Complete!"
echo "=========================================="
echo ""
echo "Service Principal Details (save these securely):"
echo "  Client ID: $CLIENT_ID"
echo "  Tenant ID: $TENANT_ID"
echo "  Subscription ID: $SUBSCRIPTION_ID"
echo ""
echo "Database password has been created and stored in secret: db-password"
echo ""
echo "To delete this service principal later:"
echo "  az ad sp delete --id $CLIENT_ID"
echo ""
echo "Next steps:"
echo "1. Verify provider: kubectl get providers"
echo "2. Deploy XRDs: kubectl apply -f manifests/xrds/"
echo "3. Deploy compositions: kubectl apply -f manifests/compositions/"
echo "4. Create database: kubectl apply -f examples/database-dev.yaml"
echo ""

