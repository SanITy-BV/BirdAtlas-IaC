param location string
param sqlServerName string
param sqlDatabaseName string
param sqlServerAdministratorLogin string
@secure()
param sqlServerAdministratorLoginPassword string
param sqlSku object
param tags object

resource sqlServer 'Microsoft.Sql/servers@2019-06-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlServerAdministratorLogin
    administratorLoginPassword: sqlServerAdministratorLoginPassword
    version: '12.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2020-08-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: sqlSku
  tags: tags
}

resource sqlFirewallRuleAllowAllAzureIPs 'Microsoft.Sql/servers/firewallRules@2014-04-01' = {
  parent: sqlServer
  name: 'AllowAllAzureIPs'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}
