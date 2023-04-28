resource "my_alert_rule" "rule_196" {
  name = "AD FS Remote Auth Sync Connection"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P1D
  severity = Medium
  query = <<EOF
// Adjust this to use a longer timeframe to identify ADFS servers
//let lookback = 0d;
// Adjust this to adjust detection timeframe
//let timeframe = 1d;
// SamAccountName of AD FS Service Account. Filter on the use of a specific AD FS user account
//let adfsuser = 'adfsadmin';
// Identify ADFS Servers
let ADFS_Servers = (
    SecurityEvent
    //| where TimeGenerated > ago(timeframe+lookback)
    | where EventSourceName == 'AD FS Auditing'
    | distinct Computer
);
SecurityEvent
    //| where TimeGenerated > ago(timeframe)
    | where Computer in~ (ADFS_Servers)
    // A token of type 'http://schemas.microsoft.com/ws/2006/05/servicemodel/tokens/SecureConversation'
    // for relying party '-' was successfully authenticated.
    | where EventID == 412
    | extend EventData = parse_xml(EventData).EventData.Data
    | extend InstanceId = tostring(EventData[0])
| join kind=inner
(
    SecurityEvent
    //| where TimeGenerated > ago(timeframe)
    | where Computer in~ (ADFS_Servers)
    // Events to identify caller identity from event 412
    | where EventID == 501
    | extend EventData = parse_xml(EventData).EventData.Data
    | where tostring(EventData[1]) contains 'identity/claims/name'
    | extend InstanceId = tostring(EventData[0])
    | extend ClaimsName = tostring(EventData[2])
    // Filter on the use of a specific AD FS user account
    //| where ClaimsName contains adfsuser
)
on $left.InstanceId == $right.InstanceId
| join kind=inner
(
    SecurityEvent
    | where EventID == 5156
    | where Computer in~ (ADFS_Servers)
    | extend EventData = parse_xml(EventData).EventData.Data
    | mv-expand bagexpansion=array EventData
    | evaluate bag_unpack(EventData)
    | extend Key = tostring(column_ifexists('@Name', "")), Value = column_ifexists('#text', "")
    | evaluate pivot(Key, any(Value), TimeGenerated, Computer, EventID)
    | extend DestPort = column_ifexists("DestPort", ""),
          Direction = column_ifexists("Direction", ""),
          Application = column_ifexists("Application", ""),
          DestAddress = column_ifexists("DestAddress", ""),
          SourceAddress = column_ifexists("SourceAddress", ""),
          SourcePort = column_ifexists("SourcePort", "")
    // Look for inbound connections from endpoints on port 80
    | where DestPort == 80 and Direction == '%%14592' and Application == 'System'
    | where DestAddress !in ('::1','0:0:0:0:0:0:0:1') 
)
on $left.Computer == $right.Computer
| project TimeGenerated, Computer, ClaimsName, SourceAddress, SourcePort
| extend HostCustomEntity = Computer, AccountCustomEntity = ClaimsName, IPCustomEntity = SourceAddress
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
  tactics = ['Collection']
  techniques = ['T1005']
  display_name = AD FS Remote Auth Sync Connection
  description = <<EOT
This detection uses Security events from the "AD FS Auditing" provider to detect suspicious authentication events on an AD FS server. The results then get
correlated with events from the Windows Filtering Platform (WFP) to detect suspicious incoming network traffic on port 80 on the AD FS server.
This could be a sign of a threat actor trying to use replication services on the AD FS server to get its configuration settings and extract
sensitive information such as AD FS certificates.
In order to use this query you need to enable AD FS auditing on the AD FS Server.
References: 
https://docs.microsoft.com/windows-server/identity/ad-fs/troubleshooting/ad-fs-tshoot-logging
https://twitter.com/OTR_Community/status/1387038995016732672

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
