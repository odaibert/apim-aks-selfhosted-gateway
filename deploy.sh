#!/bin/bash

# ==============================================================================
# Azure APIM Self-Hosted Gateway Deployment Script
# ==============================================================================
# This script solves the 'chicken-and-egg' problem:
# 1. Deploy infrastructure (APIM + AKS) via Bicep FIRST
# 2. THEN retrieve APIM gateway URL and generate token programmatically
# 3. Finally deploy the self-hosted gateway via Helm with the retrieved values
# ==============================================================================

set -euo pipefail
# ==============================================================================
# Configuration Variables
# ==============================================================================

RESOURCE_GROUP="rg-apim-hybrid-demo"
LOCATION="eastus"
BASE_NAME="apim-hybrid-demo"
GATEWAY_NAME="west-gateway"
HELM_RELEASE_NAME="apim-gateway"
HELM_NAMESPACE="apim-gateway"
REPLICA_COUNT=2
TOKEN_EXPIRY_DAYS=30

# Derived names (must match Bicep output)
AKS_CLUSTER_NAME="${BASE_NAME}-aks"
APIM_NAME="${BASE_NAME}-apim"

echo "=============================================================================="
echo "Starting APIM Self-Hosted Gateway Deployment"
echo "=============================================================================="
echo ""
echo "Resource Group: $RESOURCE_GROUP"
echo "APIM Name: $APIM_NAME"
echo "AKS Cluster: $AKS_CLUSTER_NAME"
echo "Gateway Name: $GATEWAY_NAME"
echo ""

# ==============================================================================
# Step 1: Create Resource Group
# ==============================================================================

echo "[Step 1/5] Creating Resource Group..."
az group create --name $RESOURCE_GROUP --location $LOCATION --output none
echo "Resource Group '$RESOURCE_GROUP' created successfully."
echo ""

# ==============================================================================
# Step 2: Deploy Bicep Template
# ==============================================================================
# CRITICAL: The Bicep template creates both APIM and the 'west-gateway' child
# resource. This MUST complete before we can generate a token for the gateway.
# ==============================================================================

echo "[Step 2/5] Deploying Bicep template (this may take 30-45 minutes for APIM)..."
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters baseName=$BASE_NAME \
  --output none

echo "Bicep deployment completed successfully."
echo ""

# ==============================================================================
# Step 3: Get AKS Credentials
# ==============================================================================

echo "[Step 3/5] Retrieving AKS credentials..."
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing

echo "AKS credentials configured for kubectl."
echo ""

# ==============================================================================
# Step 4: Retrieve APIM Configuration and Generate Gateway Token
# ==============================================================================
# CHICKEN-AND-EGG SOLUTION:
# - The APIM instance and gateway resource were created in Step 2 (Bicep)
# - NOW we can programmatically retrieve the gateway URL and generate a token
# - This eliminates any need for hardcoded secrets
# ==============================================================================

echo "[Step 4/5] Retrieving APIM configuration and generating gateway token..."

# Get the APIM gateway URL using az apim show
GATEWAY_URL=$(az apim show \
  --resource-group $RESOURCE_GROUP \
  --name $APIM_NAME \
  --query 'gatewayUrl' \
  --output tsv)

echo "APIM Gateway URL: $GATEWAY_URL"

# Calculate token expiry (30 days from now)
EXPIRY_DATE=$(date -u -d "+${TOKEN_EXPIRY_DAYS} days" '+%Y-%m-%dT%H:%M:%SZ')

# Generate the gateway token using az apim gateway generate-token
# This token authenticates the self-hosted gateway to the APIM control plane
GATEWAY_TOKEN=$(az apim gateway generate-token \
  --resource-group $RESOURCE_GROUP \
  --gateway-id $GATEWAY_NAME \
  --service-name $APIM_NAME \
  --expiry $EXPIRY_DATE \
  --query 'value' \
  --output tsv)

echo "Gateway token generated (expires: $EXPIRY_DATE)"
echo ""

# ==============================================================================
# Step 5: Deploy Self-Hosted Gateway via Helm
# ==============================================================================
# Helm Chart: azure-apim-gateway
# Repository: https://azure.github.io/api-management-self-hosted-gateway/helm-charts/
# ==============================================================================

echo "[Step 5/5] Deploying self-hosted gateway via Helm..."

# Add the Azure APIM Helm repository
helm repo add azure-apim-gateway https://azure.github.io/api-management-self-hosted-gateway/helm-charts/
helm repo update

# Create namespace for the gateway
kubectl create namespace $HELM_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Build the configuration endpoint URL
# Format: {gatewayUrl}/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.ApiManagement/service/{apim}/gateways/{gateway}?api-version=2022-08-01
SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)
CONFIG_URL="${GATEWAY_URL}/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_NAME}/gateways/${GATEWAY_NAME}?api-version=2022-08-01"

echo "Configuration URL: $CONFIG_URL"

# Install/Upgrade the Helm chart
# - gateway.configuration.uri: Points to the APIM configuration endpoint
# - gateway.auth.key: The generated SAS token for authentication
# - replicaCount: Set to 2 for high availability
helm upgrade --install $HELM_RELEASE_NAME azure-apim-gateway/azure-api-management-gateway \
  --namespace $HELM_NAMESPACE \
  --set gateway.configuration.uri="$CONFIG_URL" \
  --set gateway.auth.key="GatewayKey $GATEWAY_TOKEN" \
  --set replicaCount=$REPLICA_COUNT \
  --set service.type=LoadBalancer

echo ""
echo "Helm deployment completed."
echo ""

# ==============================================================================
# Verification
# ==============================================================================

echo "=============================================================================="
echo "Deployment Complete!"
echo "=============================================================================="
echo ""
echo "Verifying deployment..."
echo ""

# Wait for pods to be ready
echo "Waiting for gateway pods to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=azure-api-management-gateway \
  -n $HELM_NAMESPACE \
  --timeout=300s

# Show pod status
echo ""
echo "Gateway Pods:"
kubectl get pods -n $HELM_NAMESPACE

echo ""
echo "Gateway Service:"
kubectl get svc -n $HELM_NAMESPACE

echo ""
echo "=============================================================================="
echo "Summary"
echo "=============================================================================="
echo "APIM Instance: $APIM_NAME (Control Plane in eastus)"
echo "Gateway URL: $GATEWAY_URL"
echo "AKS Cluster: $AKS_CLUSTER_NAME (Data Plane in westus3)"
echo "Self-Hosted Gateway: $GATEWAY_NAME (running with $REPLICA_COUNT replicas)"
echo "Token Expiry: $EXPIRY_DATE"
echo "=============================================================================="
echo ""
echo "Next Steps:"
echo "1. Add APIs to your APIM instance"
echo "2. Associate APIs with the '$GATEWAY_NAME' gateway"
echo "3. Test API calls through the self-hosted gateway"
echo "=============================================================================="
