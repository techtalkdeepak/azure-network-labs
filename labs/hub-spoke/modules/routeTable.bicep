// modules/routeTable.bicep

param name string
param location string
param tags object
param firewallPrivateIp string
param subnetIds array
param vnetName string
param subnet1Name string
param subnet2Name string

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

// Associate route table with subnet 1
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
}

resource subnet1 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: subnet1Name
  parent: vnet
}

resource subnet2 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: subnet2Name
  parent: vnet
}

resource subnet1RouteAssoc 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  name: subnet1Name
  parent: vnet
  properties: {
    addressPrefix: subnet1.properties.addressPrefix
    routeTable: {
      id: routeTable.id
    }
  }
}

resource subnet2RouteAssoc 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  name: subnet2Name
  parent: vnet
  properties: {
    addressPrefix: subnet2.properties.addressPrefix
    routeTable: {
      id: routeTable.id
    }
  }
  dependsOn: [subnet1RouteAssoc]
}

output routeTableId string = routeTable.id
