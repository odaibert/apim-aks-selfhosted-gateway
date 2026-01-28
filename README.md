# Azure API Management Self-Hosted Gateway on AKS

> **?? Learning Environment:** This repository provides a simplified architecture for students and learning purposes.

## ?? Overview

This solution demonstrates how to deploy an **Azure API Management (APIM) Self-Hosted Gateway** on **Azure Kubernetes Service (AKS)**. It implements a hybrid API management architecture where the control plane runs in Azure while the data plane (gateway) runs on Kubernetes.

## ?? What is a Self-Hosted Gateway?

The **Self-Hosted Gateway** is a containerized version of the Azure API Management gateway component. It allows you to run the API gateway closer to your backend services or in environments where you need more control over the gateway infrastructure.

```
???????????????????????????????????????????????????????????????????????????
?                              Azure Cloud                                 ?
?  ???????????????????????????????????????????????????????????????????    ?
?  ?                    API Management (Control Plane)                ?    ?
?  ?  • API definitions & policies                                    ?    ?
?  ?  • Developer portal                                              ?    ?
?  ?  • Analytics & monitoring                                        ?    ?
?  ?  • Subscription management                                       ?    ?
?  ???????????????????????????????????????????????????????????????????    ?
?                                    ?                                     ?
?                                    ? Configuration sync                  ?
?                                    ?                                     ?
?  ???????????????????????????????????????????????????????????????????    ?
?  ?                    AKS Cluster (Data Plane)                      ?    ?
?  ?  ???????????????????????????????????????????????????????????    ?    ?
?  ?  ?              Self-Hosted Gateway (Pod)                   ?    ?    ?
?  ?  ?  • Processes API requests                                ?    ?    ?
?  ?  ?  • Applies policies locally                              ?    ?    ?
?  ?  ?  • Reports telemetry to APIM                             ?    ?    ?
?  ?  ???????????????????????????????????????????????????????????    ?    ?
?  ???????????????????????????????????????????????????????????????????    ?
?                                    ?                                     ?
????????????????????????????????????????????????????????????????????????????
                                     ?
                                     ?
                            ???????????????????
                            ?  API Consumers  ?
                            ???????????????????
```

## ?? Why Use a Self-Hosted Gateway?

| Use Case | Description |
|----------|-------------|
| **Low Latency** | Run the gateway closer to your backend services to reduce network latency |
| **Data Sovereignty** | Keep API traffic within specific geographic regions for compliance |
| **Hybrid/Multi-Cloud** | Deploy gateways on-premises or in other cloud providers while using Azure APIM for management |
| **Edge Computing** | Process API requests at edge locations with intermittent cloud connectivity |
| **Kubernetes Native** | Integrate API management into your existing Kubernetes workflows |

## ??? Solution Architecture

This learning environment deploys a minimal setup:

| Component | Configuration | Purpose |
|-----------|---------------|---------|
| **Resource Group** | `rg-apim-learn` | Contains all Azure resources |
| **API Management** | Consumption SKU | Control plane for API definitions, policies, and analytics |
| **AKS Cluster** | 1 node, Standard_B2s | Hosts the self-hosted gateway container |
| **Self-Hosted Gateway** | 1 replica | Processes API traffic |
| **Sample API** | Swagger Petstore | Demonstrates API routing through the gateway |

## ?? Repository Structure

```
apim-aks-selfhosted-gateway/
??? main.bicep                  # Main infrastructure template (AKS + APIM + Gateway)
??? main.json                   # ARM template (compiled from Bicep)
??? import-petstore-api.bicep   # Sample API import template
??? import-petstore-api.json    # ARM template (compiled from Bicep)
??? deploy.sh                   # Automated deployment script
??? README.md                   # This file
??? prompts/
    ??? 01-create-assets.md     # Prompt to recreate the IaC assets
    ??? 02-deploy-to-azure.md   # Step-by-step deployment guide
```

## ?? Quick Start

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed and logged in
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [Helm 3.x](https://helm.sh/docs/intro/install/) installed
- Bash shell (WSL, Git Bash, or Linux/macOS terminal)
- Azure subscription with Contributor permissions

### Deploy the Solution

```bash
# Clone the repository
git clone <repository-url>
cd apim-aks-selfhosted-gateway

# Make the script executable
chmod +x deploy.sh

# Run the deployment (~10-15 minutes)
./deploy.sh
```

### Test the Deployment

```bash
# Get the gateway external IP
EXTERNAL_IP=$(kubectl get svc -n apim-gateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# Test the Petstore API
curl http://$EXTERNAL_IP/petstore/v2/pet/1
```

## ?? How It Works

### 1. Infrastructure Deployment (Bicep)

The `main.bicep` template creates:
- **AKS Cluster** with system-assigned managed identity
- **API Management** instance with Consumption SKU
- **Self-Hosted Gateway** resource registered in APIM

### 2. Gateway Token Generation

The self-hosted gateway authenticates with APIM using a SAS token:

```bash
# Generated automatically by deploy.sh
az apim gateway generate-token \
  --resource-group rg-apim-learn \
  --gateway-id my-gateway \
  --service-name apim-learn-apim \
  --expiry <30-days-from-now>
```

### 3. Helm Deployment

The gateway is deployed to AKS using the official Helm chart:

```bash
helm upgrade --install apim-gateway azure-apim-gateway/azure-api-management-gateway \
  --namespace apim-gateway \
  --set gateway.configuration.uri="<config-url>" \
  --set gateway.auth.key="GatewayKey <token>" \
  --set replicaCount=1 \
  --set service.type=LoadBalancer
```

### 4. API Association

APIs must be explicitly associated with the self-hosted gateway to be accessible through it. The `import-petstore-api.bicep` template:
1. Imports the Swagger Petstore API
2. Associates it with the `my-gateway` self-hosted gateway

## ?? Configuration

### Bicep Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `baseName` | `apim-learn` | Base name for all resources |
| `location` | `eastus` | Azure region for deployment |
| `publisherEmail` | `student@contoso.com` | APIM publisher email |
| `publisherName` | `Student` | APIM publisher name |
| `kubernetesVersion` | `1.32` | AKS Kubernetes version |
| `aksNodeVmSize` | `Standard_B2s` | VM size for AKS node |
| `gatewayName` | `my-gateway` | Self-hosted gateway name |

### Deployment Variables

Edit `deploy.sh` to customize:

```bash
RESOURCE_GROUP="rg-apim-learn"    # Resource group name
LOCATION="eastus"                  # Azure region
BASE_NAME="apim-learn"             # Resource naming prefix
GATEWAY_NAME="my-gateway"          # Gateway identifier
REPLICA_COUNT=1                    # Gateway pod replicas
TOKEN_EXPIRY_DAYS=30               # Token validity period
```

## ?? Cost Estimation

| Resource | SKU/Size | Estimated Cost |
|----------|----------|----------------|
| API Management | Consumption | ~$3.50 per million calls |
| AKS Cluster | Standard_B2s (1 node) | ~$30/month |
| Load Balancer | Standard | ~$18/month |
| **Total** | | **~$50/month** |

> **?? Tip:** Delete resources after learning sessions using `az group delete --name rg-apim-learn --yes`

## ?? Cleanup

Remove all resources to stop incurring charges:

```bash
# Delete all Azure resources
az group delete --name rg-apim-learn --yes --no-wait

# Remove kubectl context
kubectl config delete-context apim-learn-aks
```

## ?? Learning Resources

- [Azure API Management Documentation](https://docs.microsoft.com/azure/api-management/)
- [Self-Hosted Gateway Overview](https://docs.microsoft.com/azure/api-management/self-hosted-gateway-overview)
- [Deploy Self-Hosted Gateway to Kubernetes](https://docs.microsoft.com/azure/api-management/how-to-deploy-self-hosted-gateway-kubernetes)
- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)

## ?? Troubleshooting

### Gateway pod not starting

```bash
# Check pod status
kubectl get pods -n apim-gateway

# View pod logs
kubectl logs -l app.kubernetes.io/name=azure-api-management-gateway -n apim-gateway

# Describe pod for events
kubectl describe pod -l app.kubernetes.io/name=azure-api-management-gateway -n apim-gateway
```

### API not accessible through gateway

1. Verify the API is associated with the gateway in Azure Portal
2. Check the gateway is connected: Azure Portal ? APIM ? Gateways ? my-gateway
3. Ensure the LoadBalancer has an external IP: `kubectl get svc -n apim-gateway`

### Token expired

Regenerate the gateway token and update the Helm deployment:

```bash
# Generate new token
EXPIRY_DATE=$(date -u -d "+30 days" '+%Y-%m-%dT%H:%M:%SZ')
NEW_TOKEN=$(az apim gateway generate-token \
  --resource-group rg-apim-learn \
  --gateway-id my-gateway \
  --service-name apim-learn-apim \
  --expiry $EXPIRY_DATE \
  --query 'value' --output tsv)

# Update Helm release
helm upgrade apim-gateway azure-apim-gateway/azure-api-management-gateway \
  --namespace apim-gateway \
  --reuse-values \
  --set gateway.auth.key="GatewayKey $NEW_TOKEN"
```

## ?? License

This project is for educational purposes. See the [LICENSE](LICENSE) file for details.

## ?? Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
