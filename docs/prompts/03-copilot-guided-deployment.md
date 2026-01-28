# GitHub Copilot Prompts: Deploy APIM Self-Hosted Gateway on AKS

This guide provides step-by-step prompts to use with GitHub Copilot in Visual Studio to create and deploy an Azure API Management Self-Hosted Gateway on AKS.

> [!NOTE]
> Copy each prompt into GitHub Copilot Chat in Visual Studio. Wait for each step to complete before proceeding to the next one.

---

## Overview

You'll use these prompts to:
1. Create the infrastructure (Bicep templates)
2. Deploy to Azure
3. Configure the self-hosted gateway
4. Deploy to Kubernetes
5. Test the solution

**Estimated time:** 30-45 minutes

---

## Step 1: Create the Main Infrastructure Template

**What this does:** Creates a Bicep template that provisions an AKS cluster, API Management instance, and self-hosted gateway resource.

### Prompt 1.1 - Create main.bicep

```
Create a Bicep template named main.bicep that deploys:

1. An AKS cluster with:
   - System-assigned managed identity
   - Kubenet network plugin
   - Single node with Standard_B2s VM size
   - Kubernetes version 1.32

2. An Azure API Management instance with:
   - Consumption SKU
   - System-assigned managed identity

3. A self-hosted gateway resource under APIM named "my-gateway"

Parameters:
- baseName (default: "apim-learn")
- location (default: "eastus")
- publisherEmail (default: "student@contoso.com")
- publisherName (default: "Student")

Outputs:
- aksClusterName
- apimName
- apimGatewayUrl
- selfHostedGatewayName
```

---

## Step 2: Create the Sample API Import Template

**What this does:** Creates a Bicep template to import the Swagger Petstore API and associate it with the self-hosted gateway.

### Prompt 2.1 - Create import-petstore-api.bicep

```
Create a Bicep template named import-petstore-api.bicep that:

1. References an existing APIM instance (parameter: apimName)
2. References the existing self-hosted gateway named "my-gateway"
3. Imports the Swagger Petstore API v2 from: https://petstore.swagger.io/v2/swagger.json
4. Associates the API with the self-hosted gateway
5. Sets subscriptionRequired to false for easy testing

Output the API ID, name, and path.
```

---

## Step 3: Create the Deployment Script

**What this does:** Creates a bash script that orchestrates the entire deployment process.

### Prompt 3.1 - Create deploy.sh

```
Create a bash script named deploy.sh that deploys the APIM self-hosted gateway solution.

The script should:

1. Set configuration variables:
   - RESOURCE_GROUP="rg-apim-learn"
   - LOCATION="eastus"
   - BASE_NAME="apim-learn"
   - GATEWAY_NAME="my-gateway"
   - HELM_NAMESPACE="apim-gateway"
   - REPLICA_COUNT=1
   - TOKEN_EXPIRY_DAYS=30

2. Create the resource group using Azure CLI

3. Deploy main.bicep template

4. Get AKS credentials using az aks get-credentials

5. Retrieve the APIM gateway URL using az apim show

6. Generate a gateway token using az apim gateway generate-token with 30-day expiry

7. Add the Helm repository: https://azure.github.io/api-management-self-hosted-gateway/helm-charts/

8. Create Kubernetes namespace "apim-gateway"

9. Build the configuration URL for the gateway

10. Deploy the self-hosted gateway using Helm with:
    - gateway.configuration.uri set to the config URL
    - gateway.auth.key set to "GatewayKey $TOKEN"
    - replicaCount=1
    - service.type=LoadBalancer

11. Wait for the pod to be ready and show status

Include error handling with set -euo pipefail and echo statements for each step.
```

---

## Step 4: Deploy the Infrastructure

**What this does:** Executes the Azure CLI commands to deploy the infrastructure.

### Prompt 4.1 - Create Resource Group

```
Run the following Azure CLI command to create a resource group:

az group create --name rg-apim-learn --location eastus

Show me the command and explain what it does.
```

### Prompt 4.2 - Deploy Bicep Template

```
Run the following Azure CLI command to deploy the main.bicep template:

az deployment group create \
  --resource-group rg-apim-learn \
  --template-file main.bicep \
  --parameters baseName=apim-learn

This will take about 10-15 minutes. Show me the command and explain what resources are being created.
```

### Prompt 4.3 - Get AKS Credentials

```
Run the following Azure CLI command to get AKS credentials:

az aks get-credentials \
  --resource-group rg-apim-learn \
  --name apim-learn-aks \
  --overwrite-existing

Explain what this command does and how it configures kubectl.
```

---

## Step 5: Configure the Self-Hosted Gateway

**What this does:** Retrieves the APIM configuration and generates the authentication token.

### Prompt 5.1 - Get APIM Gateway URL

```
Run these Azure CLI commands to get the APIM gateway URL:

GATEWAY_URL=$(az apim show \
  --resource-group rg-apim-learn \
  --name apim-learn-apim \
  --query 'gatewayUrl' \
  --output tsv)

echo "APIM Gateway URL: $GATEWAY_URL"

Explain what the gateway URL is used for.
```

### Prompt 5.2 - Generate Gateway Token

```
Run these commands to generate a gateway token with 30-day expiry:

EXPIRY_DATE=$(date -u -d "+30 days" '+%Y-%m-%dT%H:%M:%SZ')

GATEWAY_TOKEN=$(az apim gateway generate-token \
  --resource-group rg-apim-learn \
  --gateway-id my-gateway \
  --service-name apim-learn-apim \
  --expiry $EXPIRY_DATE \
  --query 'value' \
  --output tsv)

echo "Token generated, expires: $EXPIRY_DATE"

Explain what this token is used for and why it has an expiry date.
```

### Prompt 5.3 - Build Configuration URL

```
Run these commands to build the configuration URL:

SUBSCRIPTION_ID=$(az account show --query 'id' --output tsv)

CONFIG_URL="${GATEWAY_URL}/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/rg-apim-learn/providers/Microsoft.ApiManagement/service/apim-learn-apim/gateways/my-gateway?api-version=2022-08-01"

echo "Configuration URL: $CONFIG_URL"

Explain what the configuration URL is and how the self-hosted gateway uses it.
```

---

## Step 6: Deploy to Kubernetes

**What this does:** Deploys the self-hosted gateway to the AKS cluster using Helm.

### Prompt 6.1 - Add Helm Repository

```
Run these commands to add the Azure APIM Helm repository:

helm repo add azure-apim-gateway https://azure.github.io/api-management-self-hosted-gateway/helm-charts/
helm repo update

Explain what Helm is and what this repository contains.
```

### Prompt 6.2 - Create Namespace

```
Run this command to create a Kubernetes namespace:

kubectl create namespace apim-gateway

Explain why we use a dedicated namespace for the gateway.
```

### Prompt 6.3 - Deploy the Gateway

```
Run this Helm command to deploy the self-hosted gateway:

helm upgrade --install apim-gateway azure-apim-gateway/azure-api-management-gateway \
  --namespace apim-gateway \
  --set gateway.configuration.uri="$CONFIG_URL" \
  --set gateway.auth.key="GatewayKey $GATEWAY_TOKEN" \
  --set replicaCount=1 \
  --set service.type=LoadBalancer

Explain each parameter and what the Helm chart deploys.
```

### Prompt 6.4 - Verify Deployment

```
Run these commands to verify the gateway deployment:

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=azure-api-management-gateway \
  -n apim-gateway \
  --timeout=300s

kubectl get pods -n apim-gateway
kubectl get svc -n apim-gateway

Explain what each command does and what output to expect.
```

---

## Step 7: Import Sample API

**What this does:** Imports the Petstore API and associates it with the gateway.

### Prompt 7.1 - Deploy API Import Template

```
Run this command to import the Petstore API:

az deployment group create \
  --resource-group rg-apim-learn \
  --template-file import-petstore-api.bicep \
  --parameters apimName=apim-learn-apim

Explain how APIs are associated with self-hosted gateways.
```

---

## Step 8: Test the Solution

**What this does:** Tests the deployed API through the self-hosted gateway.

### Prompt 8.1 - Get External IP

```
Run this command to get the gateway's external IP:

EXTERNAL_IP=$(kubectl get svc -n apim-gateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
echo "External IP: $EXTERNAL_IP"

Explain how the LoadBalancer service exposes the gateway.
```

### Prompt 8.2 - Test API Calls

```
Run these curl commands to test the Petstore API:

# Get a pet by ID
curl http://$EXTERNAL_IP/petstore/v2/pet/1

# List pets by status
curl "http://$EXTERNAL_IP/petstore/v2/pet/findByStatus?status=available"

# Check gateway health
curl http://$EXTERNAL_IP/status-0123456789abcdef

Explain what each endpoint does and what response to expect.
```

---

## Step 9: Clean Up Resources

**What this does:** Deletes all Azure resources to stop incurring charges.

### Prompt 9.1 - Delete Resources

```
Run these commands to clean up all resources:

# Delete Azure resource group
az group delete --name rg-apim-learn --yes --no-wait

# Remove kubectl context
kubectl config delete-context apim-learn-aks

Explain why cleanup is important for learning environments.
```

---

## Troubleshooting Prompts

Use these prompts if you encounter issues:

### Gateway Pod Not Starting

```
My gateway pod is not starting. Run these diagnostic commands and explain the output:

kubectl get pods -n apim-gateway
kubectl logs -l app.kubernetes.io/name=azure-api-management-gateway -n apim-gateway
kubectl describe pod -l app.kubernetes.io/name=azure-api-management-gateway -n apim-gateway

What are common reasons for pod startup failures?
```

### API Not Accessible

```
I deployed the API but can't access it through the gateway. Help me troubleshoot:

1. How do I verify the API is associated with the gateway in Azure portal?
2. How do I check the gateway connectivity status?
3. What should I check if the LoadBalancer has no external IP?
```

### Token Expired

```
Generate commands to regenerate an expired gateway token and update the Helm deployment:

1. Generate a new token with 30-day expiry
2. Update the Helm release with the new token using --reuse-values

Explain the --reuse-values flag.
```

---

## Complete Single Prompt (Alternative)

If you prefer to run everything at once, use this comprehensive prompt:

```
Create a complete solution to deploy an Azure API Management Self-Hosted Gateway on AKS.

Create these files:
1. main.bicep - Infrastructure template with AKS (single node, Standard_B2s), APIM (Consumption SKU), and self-hosted gateway
2. import-petstore-api.bicep - Import Petstore API and associate with gateway
3. deploy.sh - Deployment script that:
   - Creates resource group
   - Deploys Bicep templates
   - Gets AKS credentials
   - Generates gateway token
   - Deploys gateway via Helm
   - Verifies deployment

Use these defaults:
- Resource group: rg-apim-learn
- Location: eastus
- Base name: apim-learn
- Gateway name: my-gateway

After creating the files, explain how to run deploy.sh and test the solution.
```

---

## Learning Objectives

After completing these prompts, you will understand:

| Concept | Description |
|---------|-------------|
| **Hybrid API Management** | How control plane (APIM) and data plane (gateway) work together |
| **Infrastructure as Code** | Using Bicep to define Azure resources declaratively |
| **Kubernetes Deployments** | Deploying containerized workloads with Helm |
| **Token Authentication** | How self-hosted gateways authenticate with APIM |
| **API Gateway Patterns** | Routing API traffic through a gateway |

---

## Next Steps

After completing this tutorial, try these exercises:

1. **Add a custom API** - Import your own OpenAPI specification
2. **Configure policies** - Add rate limiting or request transformation
3. **Scale the gateway** - Increase replicaCount for high availability
4. **Add monitoring** - Configure Azure Monitor for the gateway
5. **Secure with HTTPS** - Add TLS termination to the gateway
