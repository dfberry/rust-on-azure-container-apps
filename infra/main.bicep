targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param rustserverExists bool

@description('Id of the user or app to assign application roles')
param principalId string

@secure()
param rust_server_env_vars object


// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}-${resourceToken}'
  location: location
  tags: tags
}

module monitoring './shared/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: 'log-${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: 'app-insights-${abbrs.insightsComponents}${resourceToken}'
  }
  scope: rg
}

module dashboard './shared/dashboard-web.bicep' = {
  name: 'dashboard'
  params: {
    name: 'dashboard-${abbrs.portalDashboards}${resourceToken}'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    location: location
    tags: tags
  }
  scope: rg
}

module registry './shared/registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    tags: tags
    name: 'reg${abbrs.containerRegistryRegistries}${resourceToken}'
  }
  scope: rg
}

// module keyVault './shared/keyvault.bicep' = {
//   name: 'keyvault'
//   params: {
//     location: location
//     tags: tags
//     name: 'kv-${abbrs.keyVaultVaults}${resourceToken}'
//     principalId: principalId
//   }
//   scope: rg
// }

module appsEnv './shared/apps-env.bicep' = {
  name: 'apps-env'
  params: {
    name: 'apps-env-${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  }
  scope: rg
}

module rustserver './app/rustserver-aca-azd-port-3000.bicep' = {
  name: 'rustserver-aca-azd-port-3000'
  params: {
    name: 'rustserver-${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    identityName: '${abbrs.managedIdentityUserAssignedIdentities}rustserver-aca-azd-port-3000-${resourceToken}'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    containerAppsEnvironmentName: appsEnv.outputs.name
    containerRegistryName: registry.outputs.name
    exists: rustserverExists
    appDefinition: rust_server_env_vars
  }
  scope: rg
}

output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP_NAME string = rg.name
output AZURE_CONTAINER_REGISTRY_NAME string = registry.outputs.name
output AZURE_CONTAINER_APP_NAME string = rustserver.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
// output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
// output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
