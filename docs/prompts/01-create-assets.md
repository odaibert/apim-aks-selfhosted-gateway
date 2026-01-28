# Prompt: Create All Assets for APIM Self-Hosted Gateway on AKS

> **?? Learning Environment:** This is a simplified architecture for students and learning purposes. Production deployments would require additional redundancy, security, and resilience configurations.

Create a minimal Infrastructure-as-Code solution for deploying Azure API Management Self-Hosted Gateway on AKS for learning purposes.

## Architecture

- Simple hybrid API Management setup with APIM control plane and self-hosted gateway on AKS
- Single-node AKS cluster with basic networking (kubenet)
- Azure API Management with Consumption SKU (cost-effective for learning)
- Self-hosted gateway with single replica

## Required Assets

### 1. main.bicep - Main Infrastructure Template

Create a Bicep template that provisions:

**AKS Cluster (Minimal Configuration):**
- System-assigned managed identity
- Kubenet network plugin (simpler than Azure CNI, no VNet required)
- Single node (node count: 1)
- Small VM size: Standard_B2s (cost-effective)
- No Availability Zones (single zone)

**Azure API Management:**
- Consumption SKU (serverless, pay-per-use, fastest deployment ~5 min)
- Public network access enabled

**Self-Hosted Gateway Resource:**
- Child resource under APIM

**Outputs:**
- AKS cluster name
- APIM name
- Gateway URL
- Self-hosted gateway name

### 2. import-petstore-api.bicep - Sample API Import Template

Create a Bicep template that:

- References existing APIM instance
- References existing self-hosted gateway
- Imports Swagger Petstore API v2 from OpenAPI spec URL: `https://petstore.swagger.io/v2/swagger.json`
- Associates the API with the self-hosted gateway
- Sets subscriptionRequired to false for easy testing

### 3. deploy.sh - Deployment Orchestration Script

Create a bash script that:

**Configuration Variables:**
```bash
RESOURCE_GROUP="rg-apim-learn"
LOCATION="eastus"
BASE_NAME="apim-learn"
GATEWAY_NAME="my-gateway"
HELM_NAMESPACE="apim-gateway"
REPLICA_COUNT=1
TOKEN_EXPIRY_DAYS=30
```

**Step 1:** Create resource group

**Step 2:** Deploy Bicep template (~5-10 min with Consumption SKU)

**Step 3:** Retrieve AKS credentials

**Step 4:** Retrieve APIM gateway URL and generate gateway token

**Step 5:** Deploy self-hosted gateway via Helm:
- Add Azure APIM Helm repository
- Create Kubernetes namespace
- Install Helm chart with single replica
- Use LoadBalancer service type

**Verification:**
- Wait for pod to be ready
- Display pod and service status

## Parameters to Expose

| Parameter | Description | Default |
|-----------|-------------|---------|
| baseName | Base name for all resources | apim-learn |
| location | Location for all resources | eastus |
| publisherEmail | Publisher email for APIM | student@contoso.com |
| publisherName | Publisher name for APIM | Student |
| kubernetesVersion | Kubernetes version | 1.32 |
| aksNodeVmSize | VM size for AKS node | Standard_B2s |
| gatewayName | Name of self-hosted gateway | my-gateway |

## Helm Configuration

| Setting | Value |
|---------|-------|
| Repository | https://azure.github.io/api-management-self-hosted-gateway/helm-charts/ |
| Chart | azure-api-management-gateway |
| gateway.configuration.uri | APIM configuration endpoint URL |
| gateway.auth.key | GatewayKey {generated-token} |
| replicaCount | 1 |
| service.type | LoadBalancer |

## Key Learning Concepts

1. **Hybrid Architecture:** Understand how APIM control plane manages configuration while self-hosted gateway handles API traffic

2. **Kubernetes Deployment:** Learn how to deploy containerized workloads using Helm charts

3. **Token-Based Authentication:** Understand how the gateway authenticates with the APIM control plane

4. **Infrastructure as Code:** Practice deploying Azure resources using Bicep templates

## Cost Optimization for Learning

| Resource | SKU/Size | Estimated Cost |
|----------|----------|----------------|
| APIM | Consumption | ~$3.50 per million calls |
| AKS | Standard_B2s (1 node) | ~$30/month |
| **Total** | | **~$30-35/month** |

> **?? Tip:** Delete resources after learning sessions to minimize costs using `az group delete`
