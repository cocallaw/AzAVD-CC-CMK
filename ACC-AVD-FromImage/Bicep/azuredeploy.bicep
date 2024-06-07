@description('Number of VMs to deploy')
@minValue(1)
@maxValue(250)
param numberOfVMs int = 1

@description('Number of Existing VMs in the hostpool')
@minValue(0)
@maxValue(5000)
param existingNumberofVMs int = 0
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
param intune bool = true
param artifactsLocation string = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02698.323.zip'

var osDiskType = 'StandardSSD_LRS'
var osDiskDeleteOption = 'Detach'
var nicDeleteOption = 'Detach'
var patchMode = 'AutomaticByOS'
var aadJoin = true
var enableHotpatching = false
var securityType = 'ConfidentialVM'
var aadJoinPreview = false

resource virtualMachineName_nic_1_numberOfVMs_existingNumberofVMs 'Microsoft.Network/networkInterfaces@2022-11-01' = [
  for i in range(0, length(range(1, numberOfVMs))): {
    name: '${virtualMachineName}-nic-${(range(1,numberOfVMs)[i]+existingNumberofVMs)}'
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

resource virtualMachineName_1_numberOfVMs_existingNumberofVMs 'Microsoft.Compute/virtualMachines@2024-03-01' = [
  for i in range(0, length(range(1, numberOfVMs))): {
    name: '${virtualMachineName}-${(range(1,numberOfVMs)[i]+existingNumberofVMs)}'
    location: resourceGroup().location
    properties: {
      hardwareProfile: {
        vmSize: virtualMachineSize
      }
      storageProfile: {
        osDisk: {
          name: '${virtualMachineName}-osdisk-${(range(1,numberOfVMs)[i]+existingNumberofVMs)}'
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
              '${virtualMachineName}-nic-${(range(1,numberOfVMs)[i]+existingNumberofVMs)}'
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
        computerName: '${virtualMachineName}-${(range(1,numberOfVMs)[i]+existingNumberofVMs)}'
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
      virtualMachineName_nic_1_numberOfVMs_existingNumberofVMs
    ]
  }
]

resource virtualMachineName_1_numberOfVMs_existingNumberofVMs_GuestAttestation 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [
  for i in range(0, length(range(1, numberOfVMs))): {
    name: '${virtualMachineName}-${(range(1,numberOfVMs)[i]+existingNumberofVMs)}/GuestAttestation'
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
      virtualMachineName_1_numberOfVMs_existingNumberofVMs
    ]
  }
]

resource virtualMachineName_1_numberOfVMs_existingNumberofVMs_Microsoft_PowerShell_DSC 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = [
  for i in range(0, length(range(1, numberOfVMs))): {
    name: '${virtualMachineName}-${(range(1,numberOfVMs)[i]+existingNumberofVMs)}/Microsoft.PowerShell.DSC'
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
      virtualMachineName_1_numberOfVMs_existingNumberofVMs_GuestAttestation
    ]
  }
]

resource virtualMachineName_1_numberOfVMs_existingNumberofVMs_AADLoginForWindows 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = [
  for i in range(0, length(range(1, numberOfVMs))): {
    name: '${virtualMachineName}-${(range(1,numberOfVMs)[i]+existingNumberofVMs)}/AADLoginForWindows'
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
      virtualMachineName_1_numberOfVMs_existingNumberofVMs_Microsoft_PowerShell_DSC
    ]
  }
]
