param appServicePlanName string
param location string
param sku object
param tags object

resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appServicePlanName
  location: location
  sku: sku
  tags: tags
}

output id string = appServicePlan.id
