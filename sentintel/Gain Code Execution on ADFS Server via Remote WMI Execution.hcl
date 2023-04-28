resource "my_alert_rule" "rule_81" {
  name = "Gain Code Execution on ADFS Server via Remote WMI Execution"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P7D
  severity = Medium
  query = <<EOF
let timeframe = 1d;
// Adjust for a longer timeframe for identifying ADFS Servers
let lookback = 6d;
// Identify ADFS Servers
let ADFS_Servers = ( union isfuzzy=true
( Event
| where TimeGenerated > ago(timeframe+lookback)
| where Source == "Microsoft-Windows-Sysmon"
| where EventID == 1
| extend EventData = parse_xml(EventData).DataItem.EventData.Data
| mv-expand bagexpansion=array EventData
| evaluate bag_unpack(EventData)
| extend Key=tostring(['@Name']), Value=['#text']
| evaluate pivot(Key, any(Value), TimeGenerated, Source, EventLog, Computer, EventLevel, EventLevelName, UserName, RenderedDescription, MG, ManagementGroupName, Type, _ResourceId)
| extend process = split(Image, '\\', -1)[-1]
| where process =~ "Microsoft.IdentityServer.ServiceHost.exe"
| distinct Computer
),
( SecurityEvent
| where TimeGenerated > ago(timeframe+lookback)
| where EventID == 4688 and SubjectLogonId != "0x3e4"
| where ProcessName has "Microsoft.IdentityServer.ServiceHost.exe"
| distinct Computer
),
(WindowsEvent
| where TimeGenerated > ago(timeframe+lookback)
| where EventID == 4688 and EventData has "0x3e4" and EventData has "Microsoft.IdentityServer.ServiceHost.exe"
| extend SubjectLogonId  = tostring(EventData.SubjectLogonId)
| where SubjectLogonId != "0x3e4"
| extend ProcessName  = tostring(EventData.ProcessName)
| where ProcessName has "Microsoft.IdentityServer.ServiceHost.exe"
| distinct Computer
)
| distinct Computer);
(union isfuzzy=true
(
SecurityEvent
| where EventID == 4688
| where TimeGenerated > ago(timeframe)
| where Computer in~ (ADFS_Servers)
| where ParentProcessName has 'wmiprvse.exe'
// Looking for rundll32.exe is based on intel from the blog linked in the description
// This can be commented out or altered to filter out known internal uses
| where CommandLine has_any ('rundll32') 
| project TimeGenerated, TargetAccount, CommandLine, Computer, Account, TargetLogonId
| extend timestamp = TimeGenerated, HostCustomEntity = Computer, AccountCustomEntity = Account
// Search for recent logons to identify lateral movement
| join kind= inner
(SecurityEvent
| where TimeGenerated > ago(timeframe)
| where EventID == 4624 and LogonType == 3
| where Account !endswith "$"
| project TargetLogonId
) on TargetLogonId
),
(
WindowsEvent
| where EventID == 4688
| where TimeGenerated > ago(timeframe)
| where Computer in~ (ADFS_Servers)
| where EventData has 'wmiprvse.exe' and EventData has_any ('rundll32') 
| extend ParentProcessName = tostring(EventData.ParentProcessName)
| where ParentProcessName has 'wmiprvse.exe'
// Looking for rundll32.exe is based on intel from the blog linked in the description
// This can be commented out or altered to filter out known internal uses
| extend CommandLine = tostring(EventData.CommandLine)
| where CommandLine has_any ('rundll32') 
| extend TargetAccount = strcat(EventData.TargetDomainName,"\\", EventData.TargetUserName)
| extend Account = strcat(EventData.TargetDomainName,"\\", EventData.TargetUserName)
| extend TargetLogonId = tostring(EventData.TargetLogonId)
| project TimeGenerated, TargetAccount, CommandLine, Computer, Account, TargetLogonId
| extend timestamp = TimeGenerated, HostCustomEntity = Computer, AccountCustomEntity = Account
// Search for recent logons to identify lateral movement
| join kind= inner
(WindowsEvent
| where TimeGenerated > ago(timeframe)
| where EventID == 4624 
| extend  LogonType = tostring(EventData.LogonType)
| where LogonType == 3
| extend Account = strcat(EventData.TargetDomainName,"\\", EventData.TargetUserName)
| where Account !endswith "$"
| extend TargetLogonId = tostring(EventData.TargetLogonId)
| project TargetLogonId
) on TargetLogonId
),
(
Event
| where TimeGenerated > ago(timeframe)
| where Source == "Microsoft-Windows-Sysmon"
// Check for WMI Events
| where Computer in~ (ADFS_Servers) and EventID in (19, 20, 21)
| extend EventData = parse_xml(EventData).DataItem.EventData.Data
| mv-expand bagexpansion=array EventData
| evaluate bag_unpack(EventData)
| extend Key=tostring(['@Name']), Value=['#text']
| evaluate pivot(Key, any(Value), TimeGenerated, Source, EventLog, Computer, EventLevel, EventLevelName, UserName, RenderedDescription, MG, ManagementGroupName, Type, _ResourceId)
| project TimeGenerated, EventType, Image, Computer, UserName
| extend timestamp = TimeGenerated, HostCustomEntity = Computer, AccountCustomEntity = UserName
)
)
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
  tactics = ['LateralMovement']
  techniques = ['T1210']
  display_name = Gain Code Execution on ADFS Server via Remote WMI Execution
  description = <<EOT
This query detects instances where an attacker has gained the ability to execute code on an ADFS Server through remote WMI Execution.
In order to use this query you need to be collecting Sysmon EventIDs 19, 20, and 21.
If you do not have Sysmon data in your workspace this query will raise an error stating:
     Failed to resolve scalar expression named "[@Name]"
For more on how WMI was used in Solorigate see https://www.microsoft.com/security/blog/2021/01/20/deep-dive-into-the-solorigate-second-stage-activation-from-sunburst-to-teardrop-and-raindrop/.
The query contains some features from the following detections to look for potentially malicious ADFS activity. See them for more details.
- ADFS Key Export (Sysmon): https://github.com/Azure/Azure-Sentinel/blob/master/Detections/SecurityEvent/ADFSKeyExportSysmon.yaml
- ADFS DKM Master Key Export: https://github.com/Azure/Azure-Sentinel/blob/master/Detections/MultipleDataSources/ADFS-DKM-MasterKey-Export.yaml
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
