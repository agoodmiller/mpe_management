resource "my_alert_rule" "rule_312" {
  name = "Security Service Registry ACL Modification"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P1D
  severity = High
  query = <<EOF
let servicelist = dynamic(['Services\\HealthService', 'Services\\Sense', 'Services\\WinDefend', 'Services\\MsSecFlt', 'Services\\DiagTrack', 'Services\\SgrmBroker', 'Services\\SgrmAgent', 'Services\\AATPSensorUpdater' , 'Services\\AATPSensor', 'Services\\mpssvc']);
let filename = dynamic(["subinacl.exe",'SetACL.exe']);
let parameters = dynamic (['/deny=SYSTEM', '/deny=S-1-5-18', '/grant=SYSTEM=r', '/grant=S-1-5-18=r', 'n:SYSTEM;p:READ', 'n1:SYSTEM;ta:remtrst;w:dacl']);
let FullAccess = dynamic(['A;CI;KA;;;SY', 'A;ID;KA;;;SY', 'A;CIID;KA;;;SY']);
let ReadAccess = dynamic(['A;CI;KR;;;SY', 'A;ID;KR;;;SY', 'A;CIID;KR;;;SY']);
let DenyAccess = dynamic(['D;CI;KR;;;SY', 'D;ID;KR;;;SY', 'D;CIID;KR;;;SY']);
let timeframe = 1d;
(union isfuzzy=true
(
SecurityEvent
| where TimeGenerated >= ago(timeframe)
| where EventID == 4670
| where ObjectType == 'Key'
| where ObjectName has_any (servicelist)
| parse EventData with * 'OldSd">' OldSd "<" *
| parse EventData with * 'NewSd">' NewSd "<" *
| extend Reason = case( (OldSd has ';;;SY' and NewSd !has ';;;SY'), 'System Account is removed', (OldSd has_any (FullAccess) and NewSd has_any (ReadAccess)) , 'System permission has been changed to read from full access', (OldSd has_any (FullAccess) and NewSd has_any (DenyAccess)), 'System account has been given denied permission', 'None')
| project TimeGenerated, Computer, Account,  ProcessName, ProcessId, ObjectName, EventData, Activity, HandleId, SubjectLogonId, OldSd, NewSd , Reason
),
(
SecurityEvent
| where TimeGenerated >= ago(timeframe)
| where EventID == 4688
| extend ProcessName = tostring(split(NewProcessName, '\\')[-1])
| where ProcessName in~ (filename) 
| where CommandLine has_any (servicelist) and CommandLine has_any (parameters)
| project TimeGenerated, Computer, Account, AccountDomain, ProcessName, ProcessNameFullPath = NewProcessName, EventID, Activity, CommandLine, EventSourceName, Type
),
(
DeviceProcessEvents
| where TimeGenerated >= ago(timeframe)
| where InitiatingProcessFileName in~ (filename) 
| where InitiatingProcessCommandLine has_any(servicelist) and InitiatingProcessCommandLine has_any (parameters)
| extend Account = iff(isnotempty(InitiatingProcessAccountUpn), InitiatingProcessAccountUpn, InitiatingProcessAccountName), Computer = DeviceName
| project TimeGenerated, Computer, Account, AccountDomain, ProcessName = InitiatingProcessFileName, ProcessNameFullPath = FolderPath, Activity = ActionType, CommandLine = InitiatingProcessCommandLine, Type, InitiatingProcessParentFileName
)
)
| extend timestamp = TimeGenerated, AccountCustomEntity = Account, HostCustomEntity = Computer
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
  tactics = ['DefenseEvasion']
  techniques = ['T1562']
  display_name = Security Service Registry ACL Modification
  description = <<EOT
Identifies attempts to modify registry ACL to evade security solutions. In the Solorigate attack, the attackers were found modifying registry permissions so services.exe cannot access the relevant registry keys to start the service.
 The detection leverages Security Event as well as MDE data to identify when specific security services registry permissions are modified. 
 Only some portions of this detection are related to Solorigate, it also includes coverage for some common tools that perform this activity. 
 Reference on guidance for enabling registry auditing:
 - https://docs.microsoft.com/windows/security/threat-protection/auditing/advanced-security-auditing-faq
 - https://docs.microsoft.com/windows/security/threat-protection/auditing/appendix-a-security-monitoring-recommendations-for-many-audit-events
 - https://docs.microsoft.com/windows/security/threat-protection/auditing/audit-registry
 - https://docs.microsoft.com/windows/security/threat-protection/auditing/event-4670
   - For the event 4670 to be created the audit policy for the registry must have auditing enabled for Write DAC and/or Write Owner
 - https://github.com/OTRF/Set-AuditRule 
 - https://docs.microsoft.com/dotnet/api/system.security.accesscontrol.registryrights?view=dotnet-plat-ext-5.0
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
