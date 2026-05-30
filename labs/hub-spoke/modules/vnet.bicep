// modules/vnet.bicep

param name string
param location string
param tags object
param addressPrefix string
param subnets array

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
      }
    }]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnet1Id string = vnet.properties.subnets[0].id
output subnet2Id string = vnet.properties.subnets[1].id
