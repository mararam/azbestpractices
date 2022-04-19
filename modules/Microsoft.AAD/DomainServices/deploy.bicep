@description('Optional. The name of the AADDS resource. Defaults to the domain name specific to the Azure ADDS service.')
param name string = domainName

@sys.description('Required. The domain name specific to the Azure ADDS service.')
param domainName string

@description('Required. The name of the sku specific to Azure ADDS Services - Standard is the default')
param sku string

@description('Required. The location to deploy the Azure ADDS Services')
param location string

@description('Optional. Additional replica set for the managed domain')
param replicaSets array = []

@description('Required. The value is the base64encoded representation of the certificate pfx file')
param pfxCertificate string

@description('Required. The value is to decrypt the provided Secure LDAP certificate pfx file')
@secure()
param pfxCertificatePassword string

@description('Required. The email recipient value to receive alerts')
param additionalRecipients string

@description('Optional. The value is to provide domain configuration type')
param domainConfigurationType string = 'FullySynced'

@description('Optional. The value is to synchronise scoped users and groups - This is enabled by default')
param filteredSync string = 'Enabled'

@description('Optional. The value is to enable clients making request using TLSv1 - This is enabled by default')
param tlsV1 string = 'Enabled'

@description('Optional. The value is to enable clients making request using NTLM v1 - This is enabled by default')
param ntlmV1 string = 'Enabled'

@description('Optional. The value is to enable synchronised users to use NTLM authentication - This is enabled by default')
param syncNtlmPasswords string = 'Enabled'

@description('Optional. The value is to enable on-premises users to authenticate against managed domain - This is enabled by default')
param syncOnPremPasswords string = 'Enabled'

@description('Optional. The value is to enable Kerberos requests that use RC4 encryption - This is enabled by default')
param kerberosRc4Encryption string = 'Enabled'

@description('Optional. The value is to enable to provide a protected channel between the Kerberos client and the KDC - This is enabled by default')
param kerberosArmoring string = 'Enabled'

@description('Optional. The value is to notify the DC Admins - This is enabled by default ')
param notifyDcAdmins string = 'Enabled'

@description('Optional. The value is to notify the Global Admins - This is enabled by default')
param notifyGlobalAdmins string = 'Enabled'

@description('Optional. The value is to enable the Secure LDAP for external services of Azure ADDS Services')
param ldapexternalaccess string = 'Enabled'

@description('Optional. The value is to enable the Secure LDAP for Azure ADDS Services')
param secureldap string = 'Enabled'

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of the diagnostic log analytics workspace.')
param diagnosticWorkspaceId string = ''

@description('Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param diagnosticEventHubAuthorizationRuleId string = ''

@description('Optional. Name of the diagnostic event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param diagnosticEventHubName string = ''

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 365

@allowed([
  'CanNotDelete'
  'NotSpecified'
  'ReadOnly'
])
@description('Optional. Specify the type of lock.')
param lock string = 'NotSpecified'

@description('Optional. Array of role assignment objects that contain the \'roleDefinitionIdOrName\' and \'principalId\' to define RBAC role assignments on this resource. In the roleDefinitionIdOrName attribute, you can provide either the display name of the role definition, or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'')
param roleAssignments array = []

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'SystemSecurity'
  'AccountManagement'
  'LogonLogoff'
  'ObjectAccess'
  'PolicyChange'
  'PrivilegeUse'
  'DetailTracking'
  'DirectoryServiceAccess'
  'AccountLogon'
])
param logsToEnable array = [
  'SystemSecurity'
  'AccountManagement'
  'LogonLogoff'
  'ObjectAccess'
  'PolicyChange'
  'PrivilegeUse'
  'DetailTracking'
  'DirectoryServiceAccess'
  'AccountLogon'
]

var diagnosticsLogs = [for log in logsToEnable: {
  category: log
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

resource domainService 'Microsoft.AAD/DomainServices@2021-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    domainName: domainName
    domainConfigurationType: domainConfigurationType
    filteredSync: filteredSync
    notificationSettings: {
      additionalRecipients: [
        additionalRecipients
      ]
      notifyDcAdmins: notifyDcAdmins
      notifyGlobalAdmins: notifyGlobalAdmins
    }
    ldapsSettings: {
      externalAccess: ldapexternalaccess
      ldaps: secureldap
      pfxCertificate: pfxCertificate
      pfxCertificatePassword: pfxCertificatePassword
    }
    replicaSets: replicaSets
    domainSecuritySettings: {
      tlsV1: tlsV1
      ntlmV1: ntlmV1
      syncNtlmPasswords: syncNtlmPasswords
      syncOnPremPasswords: syncOnPremPasswords
      kerberosRc4Encryption: kerberosRc4Encryption
      kerberosArmoring: kerberosArmoring
    }
    sku: sku
  }
}

resource domainService_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if ((!empty(diagnosticStorageAccountId)) || (!empty(diagnosticWorkspaceId)) || (!empty(diagnosticEventHubAuthorizationRuleId)) || (!empty(diagnosticEventHubName))) {
  name: '${domainName}-diagnosticSettings'
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    eventHubAuthorizationRuleId: !empty(diagnosticEventHubAuthorizationRuleId) ? diagnosticEventHubAuthorizationRuleId : null
    eventHubName: !empty(diagnosticEventHubName) ? diagnosticEventHubName : null
    logs: diagnosticsLogs
  }
  scope: domainService
}

resource domainService_lock 'Microsoft.Authorization/locks@2017-04-01' = if (lock != 'NotSpecified') {
  name: '${domainName}-${lock}-lock'
  properties: {
    level: lock
    notes: lock == 'CanNotDelete' ? 'Cannot delete resource or child resources.' : 'Cannot modify the resource or child resources.'
  }
  scope: domainService
}

module domainService_rbac '.bicep/nested_rbac.bicep' = [for (roleAssignment, index) in roleAssignments: {
  name: '${uniqueString(deployment().name, location)}-VNet-Rbac-${index}'
  params: {
    description: contains(roleAssignment, 'description') ? roleAssignment.description : ''
    principalIds: roleAssignment.principalIds
    principalType: contains(roleAssignment, 'principalType') ? roleAssignment.principalType : ''
    roleDefinitionIdOrName: roleAssignment.roleDefinitionIdOrName
    resourceId: domainService.id
  }
}]

@description('The domain name of the Azure Active Directory Domain Services(Azure ADDS)')
output name string = domainService.name

@description('The name of the resource group the Azure Active Directory Domain Services(Azure ADDS) was created in.')
output resourceGroupName string = resourceGroup().name

@description('The resource ID of the Azure Active Directory Domain Services(Azure ADDS)')
output resourceId string = domainService.id
