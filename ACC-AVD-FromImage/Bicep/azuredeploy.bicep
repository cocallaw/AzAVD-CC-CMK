@description('Number of VMs to deploy')
@minValue(1)
@maxValue(50)
param numberOfVMs int = 1
param virtualNetworkSubscriptionId string
param virtualNetworkRG string
param virtualNetworkName string
param subnetName string
param virtualMachineName string
param virtualMachineImageResourceId string
param confidentialDiskEncryptionSetId string

@allowed([
  'Standard_DC2as_v5'
  'Standard_DC4as_v5'
  'Standard_DC8as_v5'
  'Standard_DC16as_v5'
  'Standard_DC32as_v5'
  'Standard_DC48as_v5'
  'Standard_DC64as_v5'
  'Standard_DC96as_v5'
  'Standard_DC2ads_v5'
  'Standard_DC4ads_v5'
  'Standard_DC8ads_v5'
  'Standard_DC16ads_v5'
  'Standard_DC32ads_v5'
  'Standard_DC48ads_v5'
  'Standard_DC64ads_v5'
  'Standard_DC96ads_v5'
])
param virtualMachineSize string = 'Standard_DC2as_v5'
param adminUsername string

@secure()
param adminPassword string
param hostpoolName string

@secure()
param hostpoolToken string
param artifactsLocation string = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02698.323.zip'

var osDiskType = 'StandardSSD_LRS'
var osDiskDeleteOption = 'Detach'
var nicDeleteOption = 'Detach'
var patchMode = 'AutomaticByOS'
var aadLoginExtensionName = 'AADLoginForWindows'
var aadJoin = true
var enableHotpatching = false
var intune = false
var securityType = 'ConfidentialVM'
var aadJoinPreview = false

resource virtualMachineName_nic_0_numberOfVMs 'Microsoft.Network/networkInterfaces@2022-11-01' = [
  for i in range(0, length(range(0, numberOfVMs))): {
    name: '${virtualMachineName}-nic-${range(0,numberOfVMs)[i]}'
    location: resourceGroup().location
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: resourceId(
                virtualNetworkSubscriptionId,
                virtualNetworkRG,
                'Microsoft.Network/virtualNetworks/subnets',
                virtualNetworkName,
                subnetName
              )
            }
            privateIPAllocationMethod: 'Dynamic'
          }
        }
      ]
    }
    dependsOn: []
  }
]

resource virtualMachineName_0_numberOfVMs 'Microsoft.Compute/virtualMachines@2024-03-01' = [
  for i in range(0, length(range(0, numberOfVMs))): {
    name: '${virtualMachineName}-${range(0,numberOfVMs)[i]}'
    location: resourceGroup().location
    properties: {
      hardwareProfile: {
        vmSize: virtualMachineSize
      }
      storageProfile: {
        osDisk: {
          createOption: 'fromImage'
          managedDisk: {
            storageAccountType: osDiskType
            securityProfile: {
              securityEncryptionType: 'DiskWithVMGuestState'
              diskEncryptionSet: {
                id: confidentialDiskEncryptionSetId
              }
            }
          }
          deleteOption: osDiskDeleteOption
        }
        imageReference: {
          id: virtualMachineImageResourceId
        }
      }
      networkProfile: {
        networkInterfaces: [
          {
            id: resourceId(
              'Microsoft.Network/networkInterfaces',
              '${virtualMachineName}-nic-${range(0,numberOfVMs)[i]}'
            )
            properties: {
              deleteOption: nicDeleteOption
            }
          }
        ]
      }
      additionalCapabilities: {
        hibernationEnabled: false
      }
      osProfile: {
        computerName: '${virtualMachineName}-${range(0,numberOfVMs)[i]}'
        adminUsername: adminUsername
        adminPassword: adminPassword
        windowsConfiguration: {
          enableAutomaticUpdates: true
          provisionVMAgent: true
          patchSettings: {
            enableHotpatching: enableHotpatching
            patchMode: patchMode
          }
        }
      }
      licenseType: 'Windows_Client'
      securityProfile: {
        securityType: securityType
        uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
        }
      }
    }
    identity: {
      type: 'SystemAssigned'
    }
    dependsOn: [
      virtualMachineName_nic_0_numberOfVMs
    ]
  }
]

resource virtualMachineName_0_numberOfVMs_GuestAttestation 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [
  for i in range(0, numberOfVMs): {
    name: '${virtualMachineName}-${range(0,numberOfVMs)[i]}/GuestAttestation'
    location: resourceGroup().location
    properties: {
      publisher: 'Microsoft.Azure.Security.WindowsAttestation'
      type: 'GuestAttestation'
      typeHandlerVersion: '1.0'
      autoUpgradeMinorVersion: true
      settings: {
        AttestationConfig: {
          MaaSettings: {
            maaEndpoint: ''
            maaTenantName: 'GuestAttestation'
          }
          AscSettings: {
            ascReportingEndpoint: ''
            ascReportingFrequency: ''
          }
          useCustomToken: 'false'
          disableAlerts: 'false'
        }
      }
    }
    dependsOn: [
      virtualMachineName_0_numberOfVMs
    ]
  }
]

resource virtualMachineName_0_numberOfVMs_Microsoft_PowerShell_DSC 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = [
  for i in range(0, numberOfVMs): {
    name: '${virtualMachineName}-${range(0,numberOfVMs)[i]}/Microsoft.PowerShell.DSC'
    location: resourceGroup().location
    properties: {
      publisher: 'Microsoft.Powershell'
      type: 'DSC'
      typeHandlerVersion: '2.73'
      autoUpgradeMinorVersion: true
      settings: {
        modulesUrl: artifactsLocation
        configurationFunction: 'Configuration.ps1\\AddSessionHost'
        properties: {
          hostPoolName: hostpoolName
          registrationInfoTokenCredential: {
            UserName: 'PLACEHOLDER_DO_NOT_USE'
            Password: 'PrivateSettingsRef:RegistrationInfoToken'
          }
          aadJoin: aadJoin
          UseAgentDownloadEndpoint: true
          aadJoinPreview: aadJoinPreview
          mdmId: (intune ? '0000000a-0000-0000-c000-000000000000' : '')
          sessionHostConfigurationLastUpdateTime: ''
        }
      }
      protectedSettings: {
        Items: {
          RegistrationInfoToken: hostpoolToken
        }
      }
    }
    dependsOn: [
      virtualMachineName_0_numberOfVMs_GuestAttestation
    ]
  }
]

resource virtualMachineName_0_numberOfVMs_aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = [
  for i in range(0, length(range(0, numberOfVMs))): {
    name: '${virtualMachineName}-${range(0,numberOfVMs)[i]}/${aadLoginExtensionName}'
    location: resourceGroup().location
    properties: {
      publisher: 'Microsoft.Azure.ActiveDirectory'
      type: 'AADLoginForWindows'
      typeHandlerVersion: '2.0'
      autoUpgradeMinorVersion: true
      settings: (intune
        ? {
            mdmId: '0000000a-0000-0000-c000-000000000000'
          }
        : json('null'))
    }
    dependsOn: [
      virtualMachineName_0_numberOfVMs_Microsoft_PowerShell_DSC
    ]
  }
]
