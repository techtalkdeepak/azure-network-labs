// modules/peering.bicep

param localVnetName string
param remoteVnetId string
param peeringName string
param allowGatewayTransit bool = false
param useRemoteGateways bool = false
param allowForwardedTraffic bool = true

resource localVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  name: peeringName
  parent: localVnet
  properties: {
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
  }
}

output peeringId string = peering.id
