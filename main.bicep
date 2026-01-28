// ==============================================================================
// Azure API Management Self-Hosted Gateway on AKS - Infrastructure as Code
// ==============================================================================
@description('Base name for all resources')
param baseName string = 'apim-hybrid-demo'
@description('Location for the AKS cluster (must support Availability Zones)')
param aksLocation string = 'westus3'

@description('Location for the APIM instance (control plane)')
param apimLocation string = 'eastus'
@description('Publisher email for APIM')
param publisherEmail string = 'admin@contoso.com'

@description('Publisher name for APIM')
param publisherName string = 'Contoso'

@description('Kubernetes version for AKS')
param kubernetesVersion string = '1.32'
@description('VM size for AKS nodes')
param aksNodeVmSize string = 'Standard_DS2_v2'

@description('Number of nodes in the AKS cluster')
@minValue(1)
@maxValue(10)
param aksNodeCount int = 3
@description('Name of the self-hosted gateway')
param gatewayName string = 'west-gateway'

@description('Description of the self-hosted gateway')
param gatewayDescription string = 'Self-hosted gateway deployed to AKS in West US 3'

// ==============================================================================
// Variables
// ==============================================================================

var aksClusterName = '${baseName}-aks'
var apimName = '${baseName}-apim'
var aksDnsPrefix = '${baseName}-dns'
var vnetName = '${baseName}-vnet'
var aksSubnetName = 'aks-subnet'
var vnetAddressPrefix = '10.0.0.0/16'
var aksSubnetAddressPrefix = '10.0.0.0/22'

// ==============================================================================
// Resources
// ==============================================================================

// Virtual Network for AKS (required for Azure CNI)
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: aksLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: aksSubnetName
        properties: {
          addressPrefix: aksSubnetAddressPrefix
        }
      }
    ]
  }
}

// AKS Cluster with Azure CNI and Availability Zones
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: aksClusterName
  location: aksLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: aksDnsPrefix
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
      loadBalancerSku: 'standard'
    }
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: aksNodeCount
        vmSize: aksNodeVmSize
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: false
        availabilityZones: [
          '1'
          '2'
        ]
        vnetSubnetID: vnet.properties.subnets[0].id
      }
    ]
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}

// Role assignment for AKS to access VNet
resource aksVnetRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vnet.id, aksCluster.id, 'Network Contributor')
  scope: vnet
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
    principalId: aksCluster.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Azure API Management with Developer SKU
resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: apimLocation
  sku: {
    name: 'Developer'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    publicNetworkAccess: 'Enabled'
  }
}

// CRITICAL: Self-Hosted Gateway Resource - Required for token generation
resource apimGateway 'Microsoft.ApiManagement/service/gateways@2023-05-01-preview' = {
  parent: apim
  name: gatewayName
  properties: {
    description: gatewayDescription
    locationData: {
      name: aksLocation
      city: 'Phoenix'
      countryOrRegion: 'United States'
    }
  }
}

// ==============================================================================
// Outputs
// ==============================================================================

@description('The name of the AKS cluster')
output aksClusterName string = aksCluster.name

@description('The name of the APIM instance')
output apimName string = apim.name

@description('The gateway URL of the APIM instance')
output apimGatewayUrl string = apim.properties.gatewayUrl
@description('The name of the self-hosted gateway')
output selfHostedGatewayName string = apimGateway.name

@description('The resource group name')
output resourceGroupName string = resourceGroup().name

@description('The AKS cluster FQDN')
output aksFqdn string = aksCluster.properties.fqdn

@description('OIDC Issuer URL for Workload Identity')
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL




