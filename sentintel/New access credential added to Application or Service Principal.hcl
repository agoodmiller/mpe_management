resource "my_alert_rule" "rule_169" {
  name = "New access credential added to Application or Service Principal"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = PT1H
  query_period = PT1H
  severity = Medium
  query = <<EOF
AuditLogs
| where OperationName has_any ("Add service principal", "Certificates and secrets management") // captures "Add service principal", "Add service principal credentials", and "Update application - Certificates and secrets management" events
| where Result =~ "success"
| mv-expand target = TargetResources
| where tostring(InitiatedBy.user.userPrincipalName) has "@" or tostring(InitiatedBy.app.displayName) has "@"
| extend targetDisplayName = tostring(TargetResources[0].displayName)
| extend targetId = tostring(TargetResources[0].id)
| extend targetType = tostring(TargetResources[0].type)
| extend keyEvents = TargetResources[0].modifiedProperties
| mv-expand keyEvents
| where keyEvents.displayName =~ "KeyDescription"
| extend new_value_set = parse_json(tostring(keyEvents.newValue))
| extend old_value_set = parse_json(tostring(keyEvents.oldValue))
| where old_value_set != "[]"
| extend diff = set_difference(new_value_set, old_value_set)
| where isnotempty(diff)
| parse diff with * "KeyIdentifier=" keyIdentifier:string ",KeyType=" keyType:string ",KeyUsage=" keyUsage:string ",DisplayName=" keyDisplayName:string "]" *
| where keyUsage == "Verify"  or keyUsage == ""
| extend UserAgent = iff(AdditionalDetails[0].key == "User-Agent",tostring(AdditionalDetails[0].value),"")
| extend InitiatingUserOrApp = iff(isnotempty(InitiatedBy.user.userPrincipalName),tostring(InitiatedBy.user.userPrincipalName), tostring(InitiatedBy.app.displayName))
| extend InitiatingIpAddress = iff(isnotempty(InitiatedBy.user.ipAddress), tostring(InitiatedBy.user.ipAddress), tostring(InitiatedBy.app.ipAddress))
// The below line is currently commented out but Microsoft Sentinel users can modify this query to show only Application or only Service Principal events in their environment
//| where targetType =~ "Application" // or targetType =~ "ServicePrincipal"
| project-away diff, new_value_set, old_value_set
| project-reorder TimeGenerated, OperationName, InitiatingUserOrApp, InitiatingIpAddress, UserAgent, targetDisplayName, targetId, targetType, keyDisplayName, keyType, keyUsage, keyIdentifier, CorrelationId, TenantId
| extend timestamp = TimeGenerated, AccountCustomEntity = InitiatingUserOrApp, IPCustomEntity = InitiatingIpAddress
EOF
  entity_mapping {
    entity_type = Account
    field_mappings {
      identifier = FullName
      column_name = AccountCustomEntity
    }
    entity_type = IP
    field_mappings {
      identifier = Address
      column_name = IPCustomEntity
    }
  }
  tactics = ['DefenseEvasion']
  techniques = ['T1550']
  display_name = New access credential added to Application or Service Principal
  description = <<EOT
This will alert when an admin or app owner account adds a new credential to an Application or Service Principal where a verify KeyCredential was already present for the app.
If a threat actor obtains access to an account with sufficient privileges and adds the alternate authentication material triggering this event, the threat actor can now authenticate as the Application or Service Principal using this credential.
Additional information on OAuth Credential Grants can be found in RFC 6749 Section 4.4 or https://docs.microsoft.com/azure/active-directory/develop/v2-oauth2-client-creds-grant-flow
For further information on AuditLogs please see https://docs.microsoft.com/azure/active-directory/reports-monitoring/reference-audit-activities.
EOT
  enabled = True
  create_incident = True
  grouping_configuration {
    enabled = False
    reopen_closed_incident = False
    lookback_duration = P1D
    entity_matching_method = AllEntities
    group_by_entities = []
    group_by_alert_details = None
    group_by_custom_details = None
  }
  suppression_duration = PT5H
  suppression_enabled = False
  event_grouping = {'aggregationKind': 'SingleAlert'}
}
