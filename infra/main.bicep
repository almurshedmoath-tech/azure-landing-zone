// Phase 2 – hub-spoke network.
// Deployed at subscription scope because it creates resource groups, then puts resources inside them.

targetScope = 'subscription'

@description('Shape of one spoke')
type spokeConfig = {
  @description('Short environment name, used in every resource name (prod, dev, test...)')
  name: string
  @description('Spoke address space; must not overlap the hub or other spokes')
  addressPrefix: string
  @description('Address range for the spoke workload subnet')
  appSubnetPrefix: string
}

@description('Region for every resource')
param location string = 'uaenorth'

@description('Hub address space')
param hubAddressPrefix string = '10.0.0.0/16'

@description('One entry per spoke. Adding a spoke = adding one entry here.')
param spokes spokeConfig[] = [
  {
    name: 'prod'
    addressPrefix: '10.1.0.0/16'
    appSubnetPrefix: '10.1.1.0/24'
  }
  {
    name: 'dev'
    addressPrefix: '10.2.0.0/16'
    appSubnetPrefix: '10.2.1.0/24'
  }
]

@description('Tags applied to every resource group and resource')
param tags object = {
  env: 'lab'
  project: 'azure-landing-zone'
}

// ---------- Hub ----------

resource hubRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-lz-hub'
  location: location
  tags: tags
}

module hubVnet 'modules/vnet.bicep' = {
  name: 'hub-vnet'
  scope: hubRg
  params: {
    name: 'vnet-hub-001'
    location: location
    addressPrefix: hubAddressPrefix
    tags: tags
    subnets: [
      {
        name: 'snet-shared'
        prefix: cidrSubnet(hubAddressPrefix, 24, 1) // 10.0.1.0/24
      }
      {
        name: 'AzureBastionSubnet' // exact name required by Bastion; min /26
        prefix: cidrSubnet(hubAddressPrefix, 26, 8) // 10.0.2.0/26
      }
      {
        name: 'GatewaySubnet' // exact name required by VPN/ExpressRoute gateways; /27 recommended
        prefix: cidrSubnet(hubAddressPrefix, 27, 24) // 10.0.3.0/27
      }
    ]
  }
}

// ---------- Spokes ----------

resource spokeRgs 'Microsoft.Resources/resourceGroups@2024-03-01' = [
  for spoke in spokes: {
    name: 'rg-lz-spoke-${spoke.name}'
    location: location
    tags: tags
  }
]

module spokeNsgs 'modules/nsg.bicep' = [
  for (spoke, i) in spokes: {
    name: 'nsg-${spoke.name}'
    scope: spokeRgs[i]
    params: {
      name: 'nsg-spoke-${spoke.name}-app'
      location: location
      tags: tags
    }
  }
]

module spokeVnets 'modules/vnet.bicep' = [
  for (spoke, i) in spokes: {
    name: 'vnet-${spoke.name}'
    scope: spokeRgs[i]
    params: {
      name: 'vnet-spoke-${spoke.name}-001'
      location: location
      addressPrefix: spoke.addressPrefix
      tags: tags
      subnets: [
        {
          name: 'snet-app'
          prefix: spoke.appSubnetPrefix
          nsgId: spokeNsgs[i].outputs.id // NSG is created first because of this reference
        }
      ]
    }
  }
]

// ---------- Peering (two links per spoke) ----------

module hubToSpoke 'modules/peering.bicep' = [
  for (spoke, i) in spokes: {
    name: 'peer-hub-to-${spoke.name}'
    scope: hubRg
    params: {
      localVnetName: hubVnet.outputs.name
      remoteVnetId: spokeVnets[i].outputs.id
      peeringName: 'peer-hub-to-${spoke.name}'
    }
  }
]

module spokeToHub 'modules/peering.bicep' = [
  for (spoke, i) in spokes: {
    name: 'peer-${spoke.name}-to-hub'
    scope: spokeRgs[i]
    params: {
      localVnetName: spokeVnets[i].outputs.name
      remoteVnetId: hubVnet.outputs.id
      peeringName: 'peer-${spoke.name}-to-hub'
    }
  }
]

output hubVnetId string = hubVnet.outputs.id
output spokeVnetIds array = [for (spoke, i) in spokes: spokeVnets[i].outputs.id]
