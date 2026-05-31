targetScope = 'subscription'

param environmentName string = 'lab'
param location string = 'australiaeast'
param hubVnetAddressPrefix string = '10.0.0.0/16'
param spoke1VnetAddressPrefix string = '10.1.0.0/16'
param spoke2VnetAddressPrefix string = '10.2.0.0/16'
param adminUsername string
@secure()
param adminPassword string
param vmSize string = 'Standard_B1s'
param tags object = {
  environment: 'lab'
  project: 'hub-spoke'
  managedBy: 'github-actions'
}

var prefix = 'hs-${environmentName}'
var rgName = 'rg-${prefix}-${location}'

// ── Resource Group ───────────────────────────────────────────

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: tags
}

// ── Hub VNet ─────────────────────────────────────────────────

module hubVnet 'modules/vnet.bicep' = {
  name: 'hubVnet'
  scope: rg
  params: {
    name: 'vnet-${prefix}-hub'
    location: location
    tags: tags
    addressPrefix: hubVnetAddressPrefix
    subnets: [
      { name: 'AzureFirewallSubnet'           addressPrefix: '10.0.0.0/26'  }
      { name: 'AzureFirewallManagementSubnet' addressPrefix: '10.0.0.64/26' }
      { name: 'AzureBastionSubnet'            addressPrefix: '10.0.1.0/27'  }
      { name: 'GatewaySubnet'                 addressPrefix: '10.0.2.0/27'  }
    ]
  }
}

// ── Azure Firewall (first — need private IP for route tables) ─

module firewall 'modules/firewall.bicep' = {
  name: 'hubFirewall'
  scope: rg
  params: {
    name: 'afw-${prefix}-hub'
    location: location
    tags: tags
    hubVnetId: hubVnet.outputs.vnetId
  }
}

// ── Route Tables (after firewall) ────────────────────────────

module rtSpoke1 'modules/routeTable.bicep' = {
  name: 'rtSpoke1'
  scope: rg
  params: {
    name: 'rt-${prefix}-spoke1'
    location: location
    tags: tags
    firewallPrivateIp: firewall.outputs.firewallPrivateIp
  }
}

module rtSpoke2 'modules/routeTable.bicep' = {
  name: 'rtSpoke2'
  scope: rg
  params: {
    name: 'rt-${prefix}-spoke2'
    location: location
    tags: tags
    firewallPrivateIp: firewall.outputs.firewallPrivateIp
  }
}

// ── Spoke VNets (after route tables) ─────────────────────────

module spoke1Vnet 'modules/vnet.bicep' = {
  name: 'spoke1Vnet'
  scope: rg
  params: {
    name: 'vnet-${prefix}-spoke1'
    location: location
    tags: tags
    addressPrefix: spoke1VnetAddressPrefix
    routeTableId: rtSpoke1.outputs.routeTableId
    subnets: [
      { name: 'snet-workload-1' addressPrefix: '10.1.0.0/24' }
      { name: 'snet-workload-2' addressPrefix: '10.1.1.0/24' }
    ]
  }
}

module spoke2Vnet 'modules/vnet.bicep' = {
  name: 'spoke2Vnet'
  scope: rg
  params: {
    name: 'vnet-${prefix}-spoke2'
    location: location
    tags: tags
    addressPrefix: spoke2VnetAddressPrefix
    routeTableId: rtSpoke2.outputs.routeTableId
    subnets: [
      { name: 'snet-workload-1' addressPrefix: '10.2.0.0/24' }
      { name: 'snet-workload-2' addressPrefix: '10.2.1.0/24' }
    ]
  }
}

// ── VNet Peerings ────────────────────────────────────────────

module peerHubToSpoke1 'modules/peering.bicep' = {
  name: 'peerHubToSpoke1'
  scope: rg
  params: {
    localVnetName: hubVnet.outputs.vnetName
    remoteVnetId: spoke1Vnet.outputs.vnetId
    peeringName: 'peer-hub-to-spoke1'
    allowForwardedTraffic: true
  }
}

module peerSpoke1ToHub 'modules/peering.bicep' = {
  name: 'peerSpoke1ToHub'
  scope: rg
  params: {
    localVnetName: spoke1Vnet.outputs.vnetName
    remoteVnetId: hubVnet.outputs.vnetId
    peeringName: 'peer-spoke1-to-hub'
    allowForwardedTraffic: true
  }
}

module peerHubToSpoke2 'modules/peering.bicep' = {
  name: 'peerHubToSpoke2'
  scope: rg
  params: {
    localVnetName: hubVnet.outputs.vnetName
    remoteVnetId: spoke2Vnet.outputs.vnetId
    peeringName: 'peer-hub-to-spoke2'
    allowForwardedTraffic: true
  }
}

module peerSpoke2ToHub 'modules/peering.bicep' = {
  name: 'peerSpoke2ToHub'
  scope: rg
  params: {
    localVnetName: spoke2Vnet.outputs.vnetName
    remoteVnetId: hubVnet.outputs.vnetId
    peeringName: 'peer-spoke2-to-hub'
    allowForwardedTraffic: true
  }
}

// ── Linux VMs — one per spoke ─────────────────────────────────

module vmSpoke1 'modules/linuxVm.bicep' = {
  name: 'vmSpoke1'
  scope: rg
  params: {
    name: 'vm-spk1-01'
    location: location
    tags: tags
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: spoke1Vnet.outputs.subnet1Id
  }
}

module vmSpoke2 'modules/linuxVm.bicep' = {
  name: 'vmSpoke2'
  scope: rg
  params: {
    name: 'vm-spk2-01'
    location: location
    tags: tags
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: spoke2Vnet.outputs.subnet1Id
  }
}

// ── Outputs ──────────────────────────────────────────────────

output resourceGroupName string = rg.name
output hubVnetId string = hubVnet.outputs.vnetId
output spoke1VnetId string = spoke1Vnet.outputs.vnetId
output spoke2VnetId string = spoke2Vnet.outputs.vnetId
output firewallPrivateIp string = firewall.outputs.firewallPrivateIp
output firewallPublicIp string = firewall.outputs.firewallPublicIp
output vmSpoke1Name string = vmSpoke1.outputs.vmName
output vmSpoke2Name string = vmSpoke2.outputs.vmName
