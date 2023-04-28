resource "my_alert_rule" "rule_88" {
  name = "User Added To Admin Grp"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = PT5M
  query_period = PT5M
  severity = Medium
  query = <<EOF
SecurityEvent
| where EventID == 4728
| where TargetUserName contains "Admin" 
or TargetUserName contains "admin"
| extend AccountCustomEntity = Account 
| extend HostCustomEntity = Computer

EOF
  entity_mapping {
    entity_type = Account
    field_mappings {
      identifier = FullName
      column_name = AccountCustomEntity
    }
    entity_type = Host
    field_mappings {
      identifier = FullName
      column_name = HostCustomEntity
    }
  }
  tactics = ['Persistence']
  techniques = ['T1098']
  display_name = User Added To Admin Grp
  description = <<EOT
'Detects When user is added to a domain group that contains the word admin (Enterprise Admins,Domain Admins,DNS Admins)'

EOT
  enabled = True
  create_incident = True
  grouping_configuration {
    enabled = True
    reopen_closed_incident = False
    lookback_duration = PT5H
    entity_matching_method = AllEntities
    group_by_entities = []
    group_by_alert_details = []
    group_by_custom_details = []
  }
  suppression_duration = PT5M
  suppression_enabled = False
  event_grouping = {'aggregationKind': 'SingleAlert'}
}
