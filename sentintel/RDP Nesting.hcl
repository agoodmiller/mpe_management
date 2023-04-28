resource "my_alert_rule" "rule_351" {
  name = "RDP Nesting"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P8D
  severity = Medium
  query = <<EOF
let endtime = 1d;
let starttime = 8d;
// The threshold below excludes matching on RDP connection computer counts of 5 or more by a given account and IP in a given day.  Change the threshold as needed.
let threshold = 5;
(union isfuzzy=true
(SecurityEvent
| where TimeGenerated >= ago(endtime)
| where EventID == 4624 and LogonType == 10
// Labeling the first RDP connection time, computer and ip
| extend FirstHop = TimeGenerated, FirstComputer = toupper(Computer), FirstIPAddress = IpAddress, Account = tolower(Account)
),
( WindowsEvent
| where TimeGenerated >= ago(endtime)
| where EventID == 4624 and EventData has ("10")
| extend LogonType = tostring(EventData.LogonType)
| where  LogonType == 10  // Labeling the first RDP connection time, computer and ip
| extend Account = strcat(tostring(EventData.TargetDomainName),"\\", tostring(EventData.TargetUserName))
| extend IpAddress = tostring(EventData.IpAddress)
| extend FirstHop = TimeGenerated, FirstComputer = toupper(Computer), FirstIPAddress = IpAddress, Account = tolower(Account)
))
| join kind=inner (
(union isfuzzy=true
(SecurityEvent
| where TimeGenerated >= ago(endtime)
| where EventID == 4624 and LogonType == 10
// Labeling the second RDP connection time, computer and ip
| extend SecondHop = TimeGenerated, SecondComputer = toupper(Computer), SecondIPAddress = IpAddress, Account = tolower(Account)
),
(WindowsEvent
| where TimeGenerated >= ago(endtime)
| where EventID == 4624 and EventData has ("10")
| extend LogonType = toint(EventData.LogonType)
| where  LogonType == 10   // Labeling the second RDP connection time, computer and ip
| extend Account = strcat(tostring(EventData.TargetDomainName),"\\", tostring(EventData.TargetUserName))
| extend IpAddress = tostring(EventData.IpAddress)
| extend SecondHop = TimeGenerated, SecondComputer = toupper(Computer), SecondIPAddress = IpAddress, Account = tolower(Account)
))
) on Account
// Make sure that the first connection is after the second connection --> SecondHop > FirstHop
// Then identify only RDP to another computer from within the first RDP connection by only choosing matches where the Computer names do not match --> FirstComputer != SecondComputer
// Then make sure the IPAddresses do not match by excluding connections from the same computers with first hop RDP connections to multiple computers --> FirstIPAddress != SecondIPAddress
| where FirstComputer != SecondComputer and FirstIPAddress != SecondIPAddress and SecondHop > FirstHop
// where the second hop occurs within 30 minutes of the first hop
| where SecondHop <= FirstHop+30m
| distinct Account, FirstHop, FirstComputer, FirstIPAddress, SecondHop, SecondComputer, SecondIPAddress, AccountType, Activity, LogonTypeName, ProcessName
// use left anti to exclude anything from the previous 7 days where the Account and IP has connected 5 or more computers.
| join kind=leftanti (
(union isfuzzy=true
(SecurityEvent
| where TimeGenerated >= ago(starttime) and TimeGenerated < ago(endtime)
| where EventID == 4624 and LogonType == 10
| summarize makeset(Computer), ComputerCount = dcount(Computer) by bin(TimeGenerated, 1d), Account = tolower(Account), IpAddress
// Connection count to computer by same account and IP to exclude counts of 5 or more on a given day
| where ComputerCount >= threshold
| mvexpand set_Computer
| extend Computer = toupper(set_Computer)
),
(WindowsEvent
| where TimeGenerated >= ago(starttime) and TimeGenerated < ago(endtime)
| where EventID == 4624 and EventData has ("10")
| extend LogonType = tostring(EventData.LogonType)
| where  LogonType == 10 
| extend Account = strcat(tostring(EventData.TargetDomainName),"\\", tostring(EventData.TargetUserName))
| extend IpAddress = tostring(EventData.IpAddress)
| summarize makeset(Computer), ComputerCount = dcount(Computer) by bin(TimeGenerated, 1d), Account = tolower(Account), IpAddress
// Connection count to computer by same account and IP to exclude counts of 5 or more on a given day
| where ComputerCount >= threshold
| mvexpand set_Computer
| extend Computer = toupper(set_Computer)
))
) on Account, $left.SecondComputer == $right.Computer, $left.SecondIPAddress == $right.IpAddress
| summarize FirstHopFirstSeen = min(FirstHop), FirstHopLastSeen = max(FirstHop) by Account, FirstComputer, FirstIPAddress, SecondHop, SecondComputer, 
SecondIPAddress, AccountType, Activity, LogonTypeName, ProcessName
| extend timestamp = FirstHopFirstSeen, AccountCustomEntity = Account, HostCustomEntity = FirstComputer, IPCustomEntity = FirstIPAddress
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
  tactics = ['LateralMovement']
  techniques = ['T1021']
  display_name = RDP Nesting
  description = <<EOT
Identifies when an RDP connection is made to a first system and then an RDP connection is made from the first system
to another system with the same account within the 60 minutes. Additionally, if historically daily
RDP connections are indicated by the logged EventID 4624 with LogonType = 10
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
