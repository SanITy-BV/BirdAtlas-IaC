// Test with:
// az deployment group what-if --name 'TestLocal' --resource-group birdatlasiac --template-file .\templates\main.bicep --parameters .\templates\parameters\DEV.parameters.json 

@description('The location into which your Azure resources should be deployed.')
param location string = resourceGroup().location

@description('Select the type of environment you want to provision. Allowed values are Production and Test.')
@allowed([
  'DEV'
  'PROD'
])
param environmentName string

@description('A unique suffix to add to resource names that need to be globally unique.')
@maxLength(13)
param resourceNameSuffix string = uniqueString(resourceGroup().id)

@description('The administrator login username for the SQL server.')
param sqlServerAdministratorLogin string = 'SQLBirdAtlas' // don't hardcode for best practice :)

@secure()
@description('The administrator login password for the SQL server.')
param sqlServerAdministratorLoginPassword string

@description('The tags to apply to each resource.')
param tags object = {
  CostCenter: 'Marketing'
  Owner: 'BirdAtlas'
  Environment: environmentName
}

// Define the names for resources.
var resourcePrefix = '${toLower(substring(environmentName,0,1))}brd' // environment + 'brd' for BirdAtlas (or any convention you like)
var appServiceAppName = '${resourcePrefix}-app${resourceNameSuffix}'
var appServicePlanName = '${resourcePrefix}-plan'
var sqlServerName = '${resourcePrefix}-sql${resourceNameSuffix}'
var sqlDatabaseName = 'BirdAtlas'
var managedIdentityName = 'WebSite'
var applicationInsightsName = 'AppInsights'
var storageAccountName = '${resourcePrefix}sa${resourceNameSuffix}'
var blobContainerNames = [
  'birds'
  'stories'
]

// Define the SKUs for each component based on the environment type.
var environmentConfigurationMap = {
  PROD: {
    appServicePlan: {
      sku: {
        name: 'S1'
        capacity: 2
      }
    }
    storageAccount: {
      sku: {
        name: 'Standard_GRS'
      }
    }
    sqlDatabase: {
      sku: {
        name: 'S1'
        tier: 'Standard'
      }
    }
  }
  DEV: {
    appServicePlan: {
      sku: {
        name: 'F1'
        capacity: 1
      }
    }
    storageAccount: {
      sku: {
        name: 'Standard_LRS'
      }
    }
    sqlDatabase: {
      sku: {
        name: 'Basic'
      }
    }
  }
}

var contributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c' // This is the built-in Azure 'Contributor' role.
var storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'

module sqlModule 'modules/sql.bicep' = {
  name: 'sqlModule'
  params: {
    location: location
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    sqlServerAdministratorLogin: sqlServerAdministratorLogin
    sqlServerAdministratorLoginPassword: sqlServerAdministratorLoginPassword
    sqlSku: environmentConfigurationMap[environmentName].sqlDatabase.sku
    tags: tags
  }
}

module appServicePlanModule 'modules/plan.bicep' = {
  name: 'appServicePlanModule'
  params: {
    appServicePlanName: appServicePlanName
    location: location
    sku: environmentConfigurationMap[environmentName].appServicePlan.sku
    tags: tags
  }
}

resource appServiceApp 'Microsoft.Web/sites@2020-06-01' = {
  name: appServiceAppName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlanModule.outputs.id // use output value
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'StorageAccountConnectionString'
          value: storageAccountConnectionString
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {} // This format is required when working with user-assigned managed identities.
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  sku: environmentConfigurationMap[environmentName].storageAccount.sku
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}
// containers in the above storage account
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = [for blobContainerName in blobContainerNames: {
  name: '${storageAccount.name}/default/${blobContainerName}'  
}]

// A user-assigned managed identity that is used by the App Service app to communicate with a storage account.
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
  tags: tags
}

// Grant the 'Contributor' role to the user-assigned managed identity, at the scope of the resource group.
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(contributorRoleDefinitionId, resourceGroup().id) // Create a GUID based on the role definition ID and scope (resource group ID). This will return the same GUID every time the template is deployed to the same resource group.
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleDefinitionId)
    principalId: managedIdentity.properties.principalId
    description: 'Grant the "Contributor" role to the user-assigned managed identity so it can access the storage account.'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2018-05-01-preview' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
  }
}
