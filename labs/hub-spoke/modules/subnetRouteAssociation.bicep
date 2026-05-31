param vnetName string
param subnetName string
param subnetAddressPrefix string
param routeTableId string

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  name: subnetName
  parent: vnet
  properties: {
    addressPrefix: subnetAddressPrefix
    routeTable: {
      id: routeTableId
    }
  }
}

output subnetId string = subnet.id
