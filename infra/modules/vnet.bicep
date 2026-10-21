// Creates one virtual network with its subnets.
// Used for the hub and for every spoke, so the same code builds all three VNets.

@description('Shape of one subnet. nsgId is optional: leave it out for subnets that must not have an NSG.')
type subnetConfig = {
  name: string
  prefix: string
  nsgId: string?
}

@description('Virtual network name, e.g. vnet-hub-001')
param name string

@description('Azure region, e.g. uaenorth')
param location string

@description('Address space in CIDR notation, e.g. 10.0.0.0/16')
param addressPrefix string

@description('Subnets to create inside the VNet')
param subnets subnetConfig[]

@description('Tags applied to the VNet')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      for s in subnets: {
        name: s.name
        properties: {
          addressPrefix: s.prefix
          networkSecurityGroup: s.?nsgId == null ? null : { id: s.nsgId! }
        }
      }
    ]
  }
}

output id string = vnet.id
output name string = vnet.name
