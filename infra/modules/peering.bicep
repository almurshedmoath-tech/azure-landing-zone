// Creates ONE direction of a VNet peering (local VNet -> remote VNet).
// A working peering needs this module twice: once from each side.

@description('Name of the VNet this peering link lives on (must be in the resource group this module deploys to)')
param localVnetName string

@description('Full resource ID of the VNet to peer with')
param remoteVnetId string

@description('Name of this peering link, e.g. peer-hub-to-prod')
param peeringName string

@description('Accept traffic that did not start in the remote VNet (needed once a hub firewall forwards traffic)')
param allowForwardedTraffic bool = true

// "existing" = refer to a VNet that is already deployed, without creating or changing it.
resource localVnet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-07-01' = {
  parent: localVnet
  name: peeringName
  properties: {
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: false // no VPN gateway in the hub yet
    useRemoteGateways: false
  }
}
