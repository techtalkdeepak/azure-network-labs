// modules/firewall.bicep

param name string
param location string
param tags object
param hubVnetId string

// ── Firewall Policy ──────────────────────────────────────────

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' = {
  name: '${name}-policy'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
  }
}

resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  name: 'DefaultRuleCollectionGroup'
  parent: firewallPolicy
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'allow-spoke-to-spoke'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'allow-spoke1-to-spoke2'
            ipProtocols: ['Any']
            sourceAddresses: ['10.1.0.0/16']
            destinationAddresses: ['10.2.0.0/16']
            destinationPorts: ['*']
          }
          {
            ruleType: 'NetworkRule'
            name: 'allow-spoke2-to-spoke1'
            ipProtocols: ['Any']
            sourceAddresses: ['10.2.0.0/16']
            destinationAddresses: ['10.1.0.0/16']
            destinationPorts: ['*']
          }
        ]
      }
    ]
  }
}

// ── Public IPs ───────────────────────────────────────────────

resource fwPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${name}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource fwMgmtPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${name}-mgmt-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ── Azure Firewall ───────────────────────────────────────────

resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'fw-ipconfig'
        properties: {
          subnet: {
            id: '${hubVnetId}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: fwPublicIp.id
          }
        }
      }
    ]
    managementIpConfiguration: {
      name: 'fw-mgmt-ipconfig'
      properties: {
        subnet: {
          id: '${hubVnetId}/subnets/AzureFirewallManagementSubnet'
        }
        publicIPAddress: {
          id: fwMgmtPublicIp.id
        }
      }
    }
  }
  dependsOn: [ruleCollectionGroup]
}

output firewallId string = firewall.id
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIp string = fwPublicIp.properties.ipAddress
output firewallPolicyId string = firewallPolicy.id
