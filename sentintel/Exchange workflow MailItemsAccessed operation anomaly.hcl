resource "my_alert_rule" "rule_137" {
  name = "Exchange workflow MailItemsAccessed operation anomaly"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P14D
  severity = Medium
  query = <<EOF
let starttime = 14d;
let endtime = 1d;
let timeframe = 1h;
let scorethreshold = 1.5;
let percentthreshold = 50;
// Preparing the time series data aggregated hourly count of MailItemsAccessd Operation in the form of multi-value array to use with time series anomaly function.
let TimeSeriesData =
OfficeActivity
| where TimeGenerated  between (startofday(ago(starttime))..startofday(ago(endtime)))
| where OfficeWorkload=~ "Exchange" and Operation =~ "MailItemsAccessed" and ResultStatus =~ "Succeeded"
| project TimeGenerated, Operation, MailboxOwnerUPN
| make-series Total=count() on TimeGenerated from startofday(ago(starttime)) to startofday(ago(endtime)) step timeframe;
let TimeSeriesAlerts = TimeSeriesData
| extend (anomalies, score, baseline) = series_decompose_anomalies(Total, scorethreshold, -1, 'linefit')
| mv-expand Total to typeof(double), TimeGenerated to typeof(datetime), anomalies to typeof(double), score to typeof(double), baseline to typeof(long)
| where anomalies > 0
| project TimeGenerated, Total, baseline, anomalies, score;
// Joining the flagged outlier from the previous step with the original dataset to present contextual information
// during the anomalyhour to analysts to conduct investigation or informed decisions.
TimeSeriesAlerts | where TimeGenerated > ago(2d)
// Join against base logs since specified timeframe to retrive records associated with the hour of anomoly
| join (
    OfficeActivity
    | where TimeGenerated > ago(2d)
    | extend DateHour = bin(TimeGenerated, 1h)
    | where OfficeWorkload=~ "Exchange" and Operation =~ "MailItemsAccessed" and ResultStatus =~ "Succeeded"
    | summarize HourlyCount=count(), TimeGeneratedMax = arg_max(TimeGenerated, *), IPAdressList = make_set(Client_IPAddress), SourceIPMax= arg_max(Client_IPAddress, *), ClientInfoStringList= make_set(ClientInfoString) by MailboxOwnerUPN, Logon_Type, TenantId, UserType, TimeGenerated = bin(TimeGenerated, 1h) 
    | where HourlyCount > 25 // Only considering operations with more than 25 hourly count to reduce False Positivies
    | order by HourlyCount desc 
) on TimeGenerated
| extend PercentofTotal = round(HourlyCount/Total, 2) * 100 
| where PercentofTotal > percentthreshold // Filter Users with count of less than 5 percent of TotalEvents per Hour to remove FPs/ users with very low count of MailItemsAccessed events
| order by PercentofTotal desc 
| project-reorder TimeGeneratedMax, Type, OfficeWorkload, Operation, UserId,SourceIPMax ,IPAdressList, ClientInfoStringList, HourlyCount, PercentofTotal, Total, baseline, score, anomalies
| extend timestamp = TimeGenerated, AccountCustomEntity = UserId
EOF
  entity_mapping {
    entity_type = Account
    field_mappings {
      identifier = FullName
      column_name = AccountCustomEntity
    }
  }
  tactics = ['Collection']
  techniques = ['T1114']
  display_name = Exchange workflow MailItemsAccessed operation anomaly
  description = <<EOT
Identifies anomalous increases in Exchange mail items accessed operations.
The query leverages KQL built-in anomaly detection algorithms to find large deviations from baseline patterns.
Sudden increases in execution frequency of sensitive actions should be further investigated for malicious activity.
Manually change scorethreshold from 1.5 to 3 or higher to reduce the noise based on outliers flagged from the query criteria.
Read more about MailItemsAccessed- https://docs.microsoft.com/microsoft-365/compliance/advanced-audit?view=o365-worldwide#mailitemsaccessed
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
