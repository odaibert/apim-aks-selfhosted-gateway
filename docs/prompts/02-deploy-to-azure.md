# Prompt: Deploy APIM Self-Hosted Gateway on Azure

> **?? Learning Environment:** This deployment is simplified for students and learning purposes.

Deploy the Azure APIM Self-Hosted Gateway on AKS solution to Azure.

## Prerequisites

Before starting the deployment, ensure you have:

- [ ] Azure CLI installed and logged in (`az login`)
- [ ] kubectl installed
- [ ] Helm 3.x installed
- [ ] Bash shell (WSL, Git Bash, or Linux/macOS terminal)
- [ ] Sufficient Azure permissions (Contributor on subscription)
- [ ] The Bicep files (`main.bicep`, `import-petstore-api.bicep`) in your working directory

## Deployment Steps

### Step 1: Set Configuration Variables

```bash
RESOURCE_GROUP="rg-apim-learn"
LOCATION="eastus"
BASE_NAME="apim-learn"
GATEWAY_NAME="my-gateway"
HELM_RELEASE_NAME="apim-gateway"
HELM_NAMESPACE="apim-gateway"
REPLICA_COUNT=1
TOKEN_EXPIRY_DAYS=30

# Derived names (must match Bicep output)
AKS_CLUSTER_NAME="${BASE_NAME}-aks"
APIM_NAME="${BASE_NAME}-apim"
```

### Step 2: Create Resource Group

```bash
az group create --name $RESOURCE_GROUP --location $LOCATION
```

### Step 3: Deploy Infrastructure via Bicep

> **Note:** This step takes ~5-10 minutes with Consumption SKU.

```bash
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters baseName=$BASE_NAME
```

### Step 4: Get AKS Credentials

```bash
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing
```

### Step 5: Retrieve APIM Gateway URL

```bash
GATEWAY_URL=$(az apim show \
  --resource-group $RESOURCE_GROUP \
  --name $APIM_NAME \
  --query 'gatewayUrl' \
  --output tsv)

echo "APIM Gateway URL: $GATEWAY_URL"
```

### Step 6: Generate Gateway Token

```bash
# Calculate token expiry (30 days from now)
EXPIRY_DATE=$(date -u -d "+${TOKEN_EXPIRY_DAYS} days" '+%Y-%m-%dT%H:%M:%SZ')

# Generate the gateway token
GATEWAY_TOKEN=$(az apim gateway generate-token \
  --resource-group $RESOURCE_GROUP \
  --gateway-id $GATEWAY_NAME \
  --service-name $APIM_NAME \
  --expiry $EXPIRY_DATE \
  --query 'value' \
  --output tsv)

echo "Gateway token generated (expires: $EXPIRY_DATE)"
```

### Step 7: Setup Helm Repository

```bash
helm repo add azure-apim-gateway https://azure.github.io/api-management-self-hosted-gateway/helm-charts/
helm repo update
```

### Step 8: Create Kubernetes Namespace

```bash
kubectl create namespace $HELM_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
```

### Step 9: Build Configuration URL

```bash
SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)

CONFIG_URL="${GATEWAY_URL}/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_NAME}/gateways/${GATEWAY_NAME}?api-version=2022-08-01"

echo "Configuration URL: $CONFIG_URL"
```

### Step 10: Deploy Self-Hosted Gateway via Helm

```bash
helm upgrade --install $HELM_RELEASE_NAME azure-apim-gateway/azure-api-management-gateway \
  --namespace $HELM_NAMESPACE \
  --set gateway.configuration.uri="$CONFIG_URL" \
  --set gateway.auth.key="GatewayKey $GATEWAY_TOKEN" \
  --set replicaCount=$REPLICA_COUNT \
  --set service.type=LoadBalancer
```

### Step 11: Verify Deployment

```bash
# Wait for pod to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=azure-api-management-gateway \
  -n $HELM_NAMESPACE \
  --timeout=300s

# Show pod status
echo "Gateway Pod:"
kubectl get pods -n $HELM_NAMESPACE

# Show service status
echo "Gateway Service:"
kubectl get svc -n $HELM_NAMESPACE
```

### Step 12: (Optional) Import Sample API

```bash
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file import-petstore-api.bicep \
  --parameters apimName=$APIM_NAME
```

## Automated Deployment (Alternative)

Instead of running steps manually, use the deployment script:

```bash
chmod +x deploy.sh
./deploy.sh
```

## Post-Deployment Testing

### Get External IP

```bash
EXTERNAL_IP=$(kubectl get svc -n $HELM_NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
echo "External IP: $EXTERNAL_IP"
```

### Test Petstore API (if imported)

```bash
# Get a pet by ID
curl http://$EXTERNAL_IP/petstore/v2/pet/1

# List pets by status
curl "http://$EXTERNAL_IP/petstore/v2/pet/findByStatus?status=available"
```

### Check Gateway Health

```bash
curl http://$EXTERNAL_IP/status-0123456789abcdef
```

## Troubleshooting

### View Gateway Logs

```bash
kubectl logs -l app.kubernetes.io/name=azure-api-management-gateway -n $HELM_NAMESPACE -f
```

### Check Gateway Configuration Sync

```bash
kubectl describe pod -l app.kubernetes.io/name=azure-api-management-gateway -n $HELM_NAMESPACE
```

### View APIM Metrics

Navigate to Azure Portal ? API Management ? Your APIM instance ? Metrics

## Cleanup

> **?? Important:** Delete resources after learning sessions to minimize costs!

```bash
# Delete the resource group and all resources
az group delete --name $RESOURCE_GROUP --yes --no-wait

# Remove local Kubernetes context
kubectl config delete-context $AKS_CLUSTER_NAME
```

## Deployment Summary

After successful deployment, you will have:

| Component | Location | Details |
|-----------|----------|---------|
| Resource Group | East US | rg-apim-learn |
| APIM Instance | East US | apim-learn-apim (Consumption SKU) |
| AKS Cluster | East US | apim-learn-aks (1 node, Standard_B2s) |
| Self-Hosted Gateway | East US | my-gateway (1 replica) |

## What You Learned

1. **Hybrid API Architecture:** How APIM control plane manages configuration while self-hosted gateway handles traffic
2. **Infrastructure as Code:** Deploying Azure resources using Bicep templates
3. **Kubernetes Basics:** Deploying workloads using Helm charts
4. **Token Authentication:** How the gateway authenticates with APIM

## Next Steps for Learning

1. **Explore the Azure Portal** - Navigate to your APIM instance and explore APIs, Products, and Subscriptions
2. **Add a new API** - Try importing a different OpenAPI specification
3. **Apply policies** - Add rate limiting or request transformation policies
4. **Check logs** - Use `kubectl logs` to understand gateway behavior

