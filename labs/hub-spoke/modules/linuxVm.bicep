// modules/linuxVm.bicep
// Boot diagnostics enabled → unlocks Serial Console in Azure Portal

param name string
param location string
param tags object
param vmSize string
param adminUsername string
@secure()
param adminPassword string
param subnetId string
param diagStorageUri string

// ── Network Interface ────────────────────────────────────────

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${name}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    enableAcceleratedNetworking: false  // B1s does not support accelerated networking
  }
}

// ── Virtual Machine ──────────────────────────────────────────

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: name
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false  // password auth enabled as requested
        provisionVMAgent: true                // required for Serial Console
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: '${name}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        deleteOption: 'Delete'    // clean up disk when VM is deleted
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'  // clean up NIC when VM is deleted
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagStorageUri  // enables Serial Console in Azure Portal
      }
    }
  }
}

output vmId string = vm.id
output vmName string = vm.name
output nicPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
