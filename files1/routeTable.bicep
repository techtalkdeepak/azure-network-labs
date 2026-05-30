// modules/routeTable.bicep
// Creates route table only — subnet association handled in vnet module

param name string
param location string
param tags object
param firewallPrivateIp string

resource routeTable 'Microsoft.Network/routeTables@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'route-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

output routeTableId string = routeTable.id
