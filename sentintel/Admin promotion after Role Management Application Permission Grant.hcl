resource "my_alert_rule" "rule_185" {
  name = "Admin promotion after Role Management Application Permission Grant"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = PT2H
  query_period = PT2H
  severity = High
  query = <<EOF
AuditLogs
| where LoggedByService =~ "Core Directory"
| where Category =~ "ApplicationManagement"
| where AADOperationType =~ "Assign"
| where ActivityDisplayName =~ "Add app role assignment to service principal"
| mv-expand TargetResources
| mv-expand TargetResources.modifiedProperties
| extend displayName_ = tostring(TargetResources_modifiedProperties.displayName)
| where displayName_ =~ "AppRole.Value"
| extend AppRole = tostring(parse_json(tostring(TargetResources_modifiedProperties.newValue)))
| where AppRole has "RoleManagement.ReadWrite.Directory"
| extend InitiatingApp = tostring(parse_json(tostring(InitiatedBy.app)).displayName)
| extend Initiator = iif(isnotempty(InitiatingApp), InitiatingApp, tostring(parse_json(tostring(InitiatedBy.user)).userPrincipalName))
| extend Target = tostring(parse_json(tostring(TargetResources.modifiedProperties[4].newValue)))
| extend TargetId = tostring(parse_json(tostring(TargetResources.modifiedProperties[3].newValue)))
| project TimeGenerated, OperationName, Initiator, Target, TargetId, Result
| join kind=innerunique (
  AuditLogs
  | where LoggedByService =~ "Core Directory"
  | where Category =~ "RoleManagement"
  | where AADOperationType in ("Assign", "AssignEligibleRole")
  | where ActivityDisplayName has_any ("Add eligible member to role", "Add member to role")
  | mv-expand TargetResources
  | mv-expand TargetResources.modifiedProperties
  | extend displayName_ = tostring(TargetResources_modifiedProperties.displayName)
  | where displayName_ =~ "Role.DisplayName"
  | extend RoleName = tostring(parse_json(tostring(TargetResources_modifiedProperties.newValue)))
  | where RoleName contains "Admin"
  | extend Initiator = tostring(parse_json(tostring(InitiatedBy.app)).displayName)
  | extend InitiatorId = tostring(parse_json(tostring(InitiatedBy.app)).servicePrincipalId)
  | extend TargetUser = tostring(TargetResources.userPrincipalName)
  | extend Target = iif(isnotempty(TargetUser), TargetUser, tostring(TargetResources.displayName))
  | extend TargetType = tostring(TargetResources.type)
  | extend TargetId = tostring(TargetResources.id)
  | project TimeGenerated, OperationName,  RoleName, Initiator, InitiatorId, Target, TargetId, TargetType, Result
) on $left.TargetId == $right.InitiatorId
| extend TimeRoleMgGrant = TimeGenerated, TimeAdminPromo = TimeGenerated1, ServicePrincipal = Initiator1, ServicePrincipalId = InitiatorId,
  TargetObject = Target1, TargetObjectId = TargetId1, TargetObjectType = TargetType
| where TimeRoleMgGrant < TimeAdminPromo
| project TimeRoleMgGrant, TimeAdminPromo, RoleName, ServicePrincipal, ServicePrincipalId, TargetObject, TargetObjectId, TargetObjectType
EOF
  entity_mapping {
    entity_type = Account
    field_mappings {
      identifier = FullName
      column_name = ServicePrincipal
    }
    entity_type = Account
    field_mappings {
      identifier = FullName
      column_name = TargetObject
    }
  }
  tactics = ['PrivilegeEscalation', 'Persistence']
  techniques = ['T1078', 'T1098']
  display_name = Admin promotion after Role Management Application Permission Grant
  description = <<EOT
This rule looks for a service principal being granted the Microsoft Graph RoleManagement.ReadWrite.Directory (application) permission before being used to add an Azure AD object or user account to an Admin directory role (i.e. Global Administrators).
This is a known attack path that is usually abused when a service principal already has the AppRoleAssignment.ReadWrite.All permission granted. This permission Allows an app to manage permission grants for application permissions to any API.
A service principal can promote itself or other service principals to admin roles (i.e. Global Administrators). This would be considered a privilege escalation technique.
Ref : https://docs.microsoft.com/graph/permissions-reference#role-management-permissions, https://docs.microsoft.com/graph/api/directoryrole-post-members?view=graph-rest-1.0&tabs=http
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
