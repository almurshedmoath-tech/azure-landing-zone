// Creates one network security group.
// With no custom rules it has only Azure's default rules (allow VNet + load balancer inbound, deny the rest).

@description('NSG name, e.g. nsg-spoke-prod-app')
param name string

@description('Azure region; must match the VNet whose subnet it will attach to')
param location string

@description('Custom security rules; empty means default rules only')
param securityRules array = []

@description('Tags applied to the NSG')
param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

output id string = nsg.id
