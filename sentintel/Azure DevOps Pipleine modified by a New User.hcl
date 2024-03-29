resource "my_alert_rule" "rule_101" {
  name = "Azure DevOps Pipleine modified by a New User"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P14D
  severity = Medium
  query = <<EOF
// Set the lookback to determine if user has created pipelines before
let timeback = 14d;
// Set the period for detections
let timeframe = 1d;
// Get a list of previous Release Pipeline creators to exclude
let releaseusers = AzureDevOpsAuditing
| where TimeGenerated > ago(timeback) and TimeGenerated < ago(timeframe)
| where OperationName in ("Release.ReleasePipelineCreated", "Release.ReleasePipelineModified")
// We want to look for users performing actions in specific projects so we create this userscope object to match on
| extend UserScope = strcat(ActorUserId, "-", ProjectName)
| summarize by UserScope;
// Get Release Pipeline creations by new users
AzureDevOpsAuditing
| where TimeGenerated > ago(timeframe)
| where OperationName =~ "Release.ReleasePipelineModified"
| extend UserScope = strcat(ActorUserId, "-", ProjectName)
| where UserScope !in (releaseusers)
| extend ActorUPN = tolower(ActorUPN)
| project-away Id, ActivityId, ActorCUID, ScopeId, ProjectId, TenantId, SourceSystem, UserScope
// See if any of these users have Azure AD alerts associated with them in the same timeframe
| join kind = leftouter (
SecurityAlert
| where TimeGenerated > ago(timeframe)
| where ProviderName == "IPC"
| extend AadUserId = tostring(parse_json(Entities)[0].AadUserId)
| summarize Alerts=count() by AadUserId) on $left.ActorUserId == $right.AadUserId
| extend Alerts = iif(isnotempty(Alerts), Alerts, 0)
// Uncomment the line below to only show results where the user as AADIdP alerts
//| where Alerts > 0
| extend timestamp = TimeGenerated, AccountCustomEntity = ActorUPN, IPCustomEntity = IpAddress
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
  tactics = ['Execution', 'DefenseEvasion']
  techniques = ['T1578', 'T1569']
  display_name = Azure DevOps Pipleine modified by a New User
  description = <<EOT
There are several potential pipeline steps that could be modified by an attacker to inject malicious code into the build cycle. A likely attacker path is the modification to an existing pipeline that they have access to. This detection looks for users modifying a pipeline when they have not previously been observed modifying or creating that pipeline before. This query also joins events with data to Azure AD Identity Protection (AAD IdP) in order to show if the user conducting the action has any associated AAD IdP  alerts, you can also chose to filter this detection to only alert when the user also has AAD IdP alerts associated with them.
EOT
  enabled = True
  create_incident = True
  grouping_configuration {
    enabled = False
    reopen_closed_incident = False
    lookback_duration = P1D
    entity_matching_method = AllEntities
    group_by_entities = []
    group_by_alert_details = []
    group_by_custom_details = []
  }
  suppression_duration = PT5H
  suppression_enabled = False
  event_grouping = {'aggregationKind': 'SingleAlert'}
}
