// ============================================================
// Hub and Spoke Lab — Azure Firewall + 2 Spokes + Linux VMs
// Region: Australia East
// ============================================================

targetScope = 'subscription'

// ── Parameters ──────────────────────────────────────────────

@description('Environment name used in resource naming')
param environmentName string = 'lab'

@description('Azure region for all resources')
param location string = 'australiaeast'

@description('Hub VNet address space')
param hubVnetAddressPrefix string = '10.0.0.0/16'

@description('Spoke 1 VNet address space')
param spoke1VnetAddressPrefix string = '10.1.0.0/16'

@description('Spoke 2 VNet address space')
param spoke2VnetAddressPrefix string = '10.2.0.0/16'

@description('Admin username for all Linux VMs')
param adminUsername string

@description('Admin password for all Linux VMs')
@secure()
param adminPassword string

@description('VM size for all Linux VMs')
param vmSize string = 'Standard_B1s'

@description('Tags applied to all resources')
param tags object = {
  environment: 'lab'
  project: 'hub-spoke'
  managedBy: 'github-actions'
}

// ── Variables ────────────────────────────────────────────────

var prefix = 'hs-${environmentName}'
var rgName = 'rg-${prefix}-${location}'

var hubFirewallSubnet     = '10.0.0.0/26'
var hubFirewallMgmtSubnet = '10.0.0.64/26'
var hubBastionSubnet      = '10.0.1.0/27'
var hubGatewaySubnet      = '10.0.2.0/27'

var spoke1Subnet1 = '10.1.0.0/24'
var spoke1Subnet2 = '10.1.1.0/24'
var spoke2Subnet1 = '10.2.0.0/24'
var spoke2Subnet2 = '10.2.1.0/24'

// ── Resource Group ───────────────────────────────────────────

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: tags
}

// ── Diagnostics Storage Account ──────────────────────────────

module diagStorage 'modules/storageAccount.bicep' = {
  name: 'diagStorage'
  scope: rg
  params: {
    name: 'stdiag${uniqueString(rg.id)}'
    location: location
    tags: tags
  }
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
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: hubFirewallSubnet
      }
      {
        name: 'AzureFirewallManagementSubnet'
        addressPrefix: hubFirewallMgmtSubnet
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: hubBastionSubnet
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: hubGatewaySubnet
      }
    ]
  }
}

// ── Azure Firewall ───────────────────────────────────────────
// Must deploy before spokes so we have the private IP for route tables

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

// ── Route Tables ─────────────────────────────────────────────
// Created after firewall so we have the private IP

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

// ── Spoke VNets (deployed after route tables) ─────────────────

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
      {
        name: 'snet-workload-1'
        addressPrefix: spoke1Subnet1
      }
      {
        name: 'snet-workload-2'
        addressPrefix: spoke1Subnet2
      }
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
      {
        name: 'snet-workload-1'
        addressPrefix: spoke2Subnet1
      }
      {
        name: 'snet-workload-2'
        addressPrefix: spoke2Subnet2
      }
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

// ── Linux VMs — Spoke 1 ──────────────────────────────────────

module vm1Spoke1 'modules/linuxVm.bicep' = {
  name: 'vm1Spoke1'
  scope: rg
  params: {
    name: 'vm-spk1-01'
    location: location
    tags: tags
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: spoke1Vnet.outputs.subnet1Id
    diagStorageUri: diagStorage.outputs.primaryBlobEndpoint
  }
}

module vm2Spoke1 'modules/linuxVm.bicep' = {
  name: 'vm2Spoke1'
  scope: rg
  params: {
    name: 'vm-spk1-02'
    location: location
    tags: tags
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: spoke1Vnet.outputs.subnet1Id
    diagStorageUri: diagStorage.outputs.primaryBlobEndpoint
  }
}

// ── Linux VMs — Spoke 2 ──────────────────────────────────────

module vm1Spoke2 'modules/linuxVm.bicep' = {
  name: 'vm1Spoke2'
  scope: rg
  params: {
    name: 'vm-spk2-01'
    location: location
    tags: tags
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: spoke2Vnet.outputs.subnet1Id
    diagStorageUri: diagStorage.outputs.primaryBlobEndpoint
  }
}

module vm2Spoke2 'modules/linuxVm.bicep' = {
  name: 'vm2Spoke2'
  scope: rg
  params: {
    name: 'vm-spk2-02'
    location: location
    tags: tags
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: spoke2Vnet.outputs.subnet1Id
    diagStorageUri: diagStorage.outputs.primaryBlobEndpoint
  }
}

// ── Outputs ──────────────────────────────────────────────────

output resourceGroupName string = rg.name
output hubVnetId string = hubVnet.outputs.vnetId
output spoke1VnetId string = spoke1Vnet.outputs.vnetId
output spoke2VnetId string = spoke2Vnet.outputs.vnetId
output firewallPrivateIp string = firewall.outputs.firewallPrivateIp
output firewallPublicIp string = firewall.outputs.firewallPublicIp
