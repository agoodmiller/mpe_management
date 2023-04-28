resource "my_alert_rule" "rule_4" {
  name = "Create incidents based on Microsoft Defender for IOT alerts"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = None
  query_period = None
  severity = None
  query = <<EOF
None
EOF
  display_name = Create incidents based on Microsoft Defender for IOT alerts
  description = <<EOT
Create incidents based on all alerts generated in Microsoft Defender for IOT
EOT
  enabled = True
  suppression_duration = None
  suppression_enabled = None
  event_grouping = None
}
