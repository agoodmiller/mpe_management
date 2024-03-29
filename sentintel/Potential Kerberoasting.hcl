resource "my_alert_rule" "rule_156" {
  name = "Potential Kerberoasting"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = PT1H
  query_period = P1D
  severity = Medium
  query = <<EOF
let starttime = 1d;
let endtime = 1h;
let prev23hThreshold = 4;
let prev1hThreshold = 15;
let Kerbevent = (union isfuzzy=true
(SecurityEvent
| where TimeGenerated >= ago(starttime)
| where EventID == 4769
| parse EventData with * 'TicketEncryptionType">' TicketEncryptionType "<" *
| where TicketEncryptionType == '0x17'
| parse EventData with * 'TicketOptions">' TicketOptions "<" *
| where TicketOptions == '0x40810000'
| parse EventData with * 'Status">' Status "<" *
| where Status == '0x0'
| parse EventData with * 'ServiceName">' ServiceName "<" *
| where ServiceName !contains "$" and ServiceName !contains "krbtgt" 
| parse EventData with * 'TargetUserName">' TargetUserName "<" *
| where TargetUserName !contains "$@" and TargetUserName !contains ServiceName
| parse EventData with * 'IpAddress">::ffff:' ClientIPAddress "<" *
),
(
WindowsEvent
| where TimeGenerated >= ago(starttime)
| where EventID == 4769 and EventData has '0x17' and EventData has '0x40810000' and EventData has 'krbtgt'
| extend TicketEncryptionType = tostring(EventData.TicketEncryptionType)
| where TicketEncryptionType == '0x17'
| extend TicketOptions = tostring(EventData.TicketOptions)
| where TicketOptions == '0x40810000'
| extend Status = tostring(EventData.Status)
| where Status == '0x0'
| extend ServiceName = tostring(EventData.ServiceName)
| where ServiceName !contains "$" and ServiceName !contains "krbtgt"
| extend TargetUserName = tostring(EventData.TargetUserName) 
| where TargetUserName !contains "$@" and TargetUserName !contains ServiceName
| extend ClientIPAddress = tostring(EventData.IpAddress) 
));
let Kerbevent23h = Kerbevent
| where TimeGenerated >= ago(starttime) and TimeGenerated < ago(endtime)
| summarize ServiceNameCountPrev23h = dcount(ServiceName), ServiceNameSet23h = makeset(ServiceName) 
by Computer, TargetUserName,TargetDomainName, ClientIPAddress, TicketOptions, TicketEncryptionType, Status
| where ServiceNameCountPrev23h < prev23hThreshold;
let Kerbevent1h = 
Kerbevent
| where TimeGenerated >= ago(endtime)
| summarize min(TimeGenerated), max(TimeGenerated), ServiceNameCountPrev1h = dcount(ServiceName), ServiceNameSet1h = makeset(ServiceName) 
by Computer, TargetUserName,TargetDomainName, ClientIPAddress, TicketOptions, TicketEncryptionType, Status;
Kerbevent1h 
| join kind=leftanti
(
Kerbevent23h
) on TargetUserName, TargetDomainName
// Threshold value set above is based on testing, this value may need to be changed for your environment.
| where ServiceNameCountPrev1h > prev1hThreshold
| project StartTimeUtc = min_TimeGenerated, EndTimeUtc = max_TimeGenerated, TargetUserName, Computer, ClientIPAddress, TicketOptions, 
TicketEncryptionType, Status, ServiceNameCountPrev1h, ServiceNameSet1h, TargetDomainName
| extend timestamp = StartTimeUtc, AccountCustomEntity = strcat(TargetDomainName,"\\", TargetUserName), HostCustomEntity = Computer, IPCustomEntity = ClientIPAddress
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
    entity_type = IP
    field_mappings {
      identifier = Address
      column_name = IPCustomEntity
    }
  }
  tactics = ['CredentialAccess']
  techniques = ['T1558']
  display_name = Potential Kerberoasting
  description = <<EOT
A service principal name (SPN) is used to uniquely identify a service instance in a Windows environment. 
Each SPN is usually associated with a service account. Organizations may have used service accounts with weak passwords in their environment. 
An attacker can try requesting Kerberos ticket-granting service (TGS) service tickets for any SPN from a domain controller (DC) which contains 
a hash of the Service account. This can then be used for offline cracking. This hunting query looks for accounts that are generating excessive 
requests to different resources within the last hour compared with the previous 24 hours.  Normal users would not make an unusually large number 
of request within a small time window. This is based on 4769 events which can be very noisy so environment based tweaking might be needed.
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
