// Bicep template to import Swagger Petstore API (v2) into Azure API Management

@description('Name of the existing API Management instance')
param apimName string = 'apim-hybrid-demo-apim'

// Reference to existing APIM instance
resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

// Reference to existing gateway
resource gateway 'Microsoft.ApiManagement/service/gateways@2023-05-01-preview' existing = {
  parent: apim
  name: 'west-gateway'
}

// Import Petstore API v2 from OpenAPI specification
resource petstoreApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'petstore-api'
  properties: {
    displayName: 'Swagger Petstore'
    description: 'Swagger Petstore API v2 - Sample Pet Store Server'
    path: 'petstore'
    protocols: [
      'https'
    ]
    format: 'openapi+json-link'
    value: 'https://petstore.swagger.io/v2/swagger.json'
    subscriptionRequired: false
  }
}

// Associate API with the self-hosted gateway (west-gateway)
resource gatewayApi 'Microsoft.ApiManagement/service/gateways/apis@2023-05-01-preview' = {
  parent: gateway
  name: petstoreApi.name
  properties: {}
}

// Outputs
output apiId string = petstoreApi.id
output apiName string = petstoreApi.name
output apiPath string = petstoreApi.properties.path

