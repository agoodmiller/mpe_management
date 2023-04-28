resource "my_alert_rule" "rule_357" {
  name = "Time series anomaly for data size transferred to public internet"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P14D
  severity = Medium
  query = <<EOF
let starttime = 14d;
let endtime = 1d;
let timeframe = 1h;
let scorethreshold = 5;
let bytessentperhourthreshold = 10;
let TimeSeriesData = (union isfuzzy=true
(
VMConnection
| where TimeGenerated between (startofday(ago(starttime))..startofday(ago(endtime)))
| where isnotempty(DestinationIp) and isnotempty(SourceIp)
| extend SourceIP = SourceIp, DestinationIP = DestinationIp
| where ipv4_is_private(DestinationIP) == false
| extend DeviceVendor = "VMConnection"
| project TimeGenerated, BytesSent, DeviceVendor
| make-series TotalBytesSent=sum(BytesSent) on TimeGenerated from startofday(ago(starttime)) to startofday(ago(endtime)) step timeframe by DeviceVendor
),
(
CommonSecurityLog
| where TimeGenerated between (startofday(ago(starttime))..startofday(ago(endtime)))
| where isnotempty(DestinationIP) and isnotempty(SourceIP)
| where ipv4_is_private(DestinationIP) == false
| project TimeGenerated, SentBytes, DeviceVendor
| make-series TotalBytesSent=sum(SentBytes) on TimeGenerated from startofday(ago(starttime)) to startofday(ago(endtime)) step timeframe by DeviceVendor
)
);
//Filter anomolies against TimeSeriesData
let TimeSeriesAlerts = materialize(TimeSeriesData
| extend (anomalies, score, baseline) = series_decompose_anomalies(TotalBytesSent, scorethreshold, -1, 'linefit')
| mv-expand TotalBytesSent to typeof(double), TimeGenerated to typeof(datetime), anomalies to typeof(double),score to typeof(double), baseline to typeof(long)
| where anomalies > 0 | extend AnomalyHour = TimeGenerated
| extend TotalBytesSentinMBperHour = round(((TotalBytesSent / 1024)/1024),2), baselinebytessentperHour = round(((baseline / 1024)/1024),2), score = round(score,2)
| project DeviceVendor, AnomalyHour, TimeGenerated, TotalBytesSentinMBperHour, baselinebytessentperHour, anomalies, score);
let AnomalyHours = materialize(TimeSeriesAlerts  | where TimeGenerated > ago(2d) | project TimeGenerated);
//Union of all BaseLogs aggregated per hour
let BaseLogs = (union isfuzzy=true
(
CommonSecurityLog
| where isnotempty(DestinationIP) and isnotempty(SourceIP)
| where TimeGenerated > ago(2d)
| extend DateHour = bin(TimeGenerated, 1h) // create a new column and round to hour
| where DateHour in ((AnomalyHours)) //filter the dataset to only selected anomaly hours
| where ipv4_is_private(DestinationIP) == false
| extend SentBytesinMB = ((SentBytes / 1024)/1024), ReceivedBytesinMB = ((ReceivedBytes / 1024)/1024)
| summarize HourlyCount = count(), TimeGeneratedMax=arg_max(TimeGenerated, *), DestinationIPList=make_set(DestinationIP, 100), DestinationPortList = make_set(DestinationPort,100), TotalSentBytesinMB = sum(SentBytesinMB), TotalReceivedBytesinMB = sum(ReceivedBytesinMB) by SourceIP, DeviceVendor, TimeGeneratedHour=bin(TimeGenerated,1h)
| where TotalSentBytesinMB > bytessentperhourthreshold
| sort by TimeGeneratedHour asc, TotalSentBytesinMB desc
| extend Rank=row_number(1, prev(TimeGeneratedHour) != TimeGeneratedHour) // Ranking the dataset per Hourly Partition
| where Rank < 10  // Selecting Top 10 records with Highest BytesSent in each Hour
| project DeviceVendor, TimeGeneratedHour, TimeGeneratedMax, SourceIP, DestinationIPList, DestinationPortList, TotalSentBytesinMB, TotalReceivedBytesinMB, Rank
),
(
VMConnection
| where isnotempty(DestinationIp) and isnotempty(SourceIp)
| where TimeGenerated > ago(2d)
| extend DateHour = bin(TimeGenerated, 1h) // create a new column and round to hour
| where DateHour in ((AnomalyHours)) //filter the dataset to only selected anomaly hours
| extend SourceIP = SourceIp, DestinationIP = DestinationIp
| where ipv4_is_private(DestinationIP) == false | extend DeviceVendor = "VMConnection"
| extend SentBytesinMB = ((BytesSent / 1024)/1024), ReceivedBytesinMB = ((BytesReceived / 1024)/1024)
| summarize HourlyCount = count(),TimeGeneratedMax=arg_max(TimeGenerated, *), DestinationIPList=make_set(DestinationIP, 100), DestinationPortList = make_set(DestinationPort, 100), TotalSentBytesinMB = sum(SentBytesinMB),TotalReceivedBytesinMB = sum(ReceivedBytesinMB) by SourceIP, DeviceVendor, TimeGeneratedHour=bin(TimeGenerated,1h)
| where TotalSentBytesinMB > bytessentperhourthreshold
| sort by TimeGeneratedHour asc, TotalSentBytesinMB desc
| extend Rank=row_number(1, prev(TimeGeneratedHour) != TimeGeneratedHour) // Ranking the dataset per Hourly Partition
| where Rank < 10  // Selecting Top 10 records with Highest BytesSent in each Hour
| project DeviceVendor, TimeGeneratedHour, TimeGeneratedMax, SourceIP, DestinationIPList, DestinationPortList, TotalSentBytesinMB, TotalReceivedBytesinMB, Rank
)
);
// Join against base logs to retrive records associated with the hour of anomoly
TimeSeriesAlerts
| where TimeGenerated > ago(2d)
| join (
    BaseLogs | extend AnomalyHour = TimeGeneratedHour
) on DeviceVendor, AnomalyHour | sort by score desc
| project DeviceVendor, AnomalyHour,TimeGeneratedMax, SourceIP, DestinationIPList, DestinationPortList, TotalSentBytesinMB, TotalReceivedBytesinMB, TotalBytesSentinMBperHour, baselinebytessentperHour, score, anomalies
| summarize EventCount = count(), StartTimeUtc= min(TimeGeneratedMax), EndTimeUtc= max(TimeGeneratedMax), SourceIPMax= arg_max(SourceIP,*), TotalBytesSentinMB = sum(TotalSentBytesinMB), TotalBytesReceivedinMB = sum(TotalReceivedBytesinMB), SourceIPList = make_set(SourceIP, 100), DestinationIPList = make_set(DestinationIPList, 100) by AnomalyHour,TotalBytesSentinMBperHour, baselinebytessentperHour, score, anomalies
| project DeviceVendor, AnomalyHour, StartTimeUtc, EndTimeUtc, SourceIPMax, SourceIPList, DestinationIPList, DestinationPortList, TotalBytesSentinMB, TotalBytesReceivedinMB, TotalBytesSentinMBperHour, baselinebytessentperHour, score, anomalies, EventCount
| extend timestamp =EndTimeUtc, IPCustomEntity = SourceIPMax
EOF
  entity_mapping {
    entity_type = IP
    field_mappings {
      identifier = Address
      column_name = IPCustomEntity
    }
  }
  tactics = ['Exfiltration']
  techniques = ['T1030']
  display_name = Time series anomaly for data size transferred to public internet
  description = <<EOT
Identifies anomalous data transfer to public networks. The query leverages built-in KQL anomaly detection algorithms that detects large deviations from a baseline pattern.
A sudden increase in data transferred to unknown public networks is an indication of data exfiltration attempts and should be investigated.
The higher the score, the further it is from the baseline value.
The output is aggregated to provide summary view of unique source IP to destination IP address and port bytes sent traffic observed in the flagged anomaly hour.
The source IP addresses which were sending less than bytessentperhourthreshold have been exluded whose value can be adjusted as needed .
You may have to run queries for individual source IP addresses from SourceIPlist to determine if anything looks suspicious
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
