resource "my_alert_rule" "rule_371" {
  name = "New user created and added to the built-in administrators group"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P1D
  severity = Low
  query = <<EOF
(union isfuzzy=true
(SecurityEvent
| where EventID == 4720
| where AccountType == "User"
| project CreatedUserTime = TimeGenerated, CreatedUserEventID = EventID, CreatedUserActivity = Activity, Computer = toupper(Computer), 
CreatedUser = tolower(TargetAccount), CreatedUserSid = TargetSid, AccountUsedToCreateUser = strcat(SubjectAccount), SidofAccountUsedToCreateUser = SubjectUserSid
),
(WindowsEvent
| where EventID == 4720
| extend SubjectUserSid = tostring(EventData.SubjectUserSid)
| extend AccountType=case(EventData.SubjectUserName endswith "$" or SubjectUserSid in ("S-1-5-18", "S-1-5-19", "S-1-5-20"), "Machine", isempty(SubjectUserSid), "", "User")
| where AccountType == "User"
| extend SubjectAccount = strcat(tostring(EventData.SubjectDomainName),"\\", tostring(EventData.SubjectUserName))
| extend TargetAccount = strcat(EventData.TargetDomainName,"\\", EventData.TargetUserName)
| extend Activity="4720 - A user account was created."
| extend TargetSid = tostring(EventData.TargetSid)
| project CreatedUserTime = TimeGenerated, CreatedUserEventID = EventID, CreatedUserActivity = Activity, Computer = toupper(Computer), 
CreatedUser = tolower(TargetAccount), CreatedUserSid = TargetSid, AccountUsedToCreateUser = strcat(SubjectAccount), SidofAccountUsedToCreateUser = SubjectUserSid
))
| join ((union isfuzzy=true
(SecurityEvent 
| where AccountType == "User"
// 4732 - A member was added to a security-enabled local group
| where EventID == 4732
// TargetSid is the builin Admins group: S-1-5-32-544
| where TargetSid == "S-1-5-32-544"
| project GroupAddTime = TimeGenerated, GroupAddEventID = EventID, GroupAddActivity = Activity, Computer = toupper(Computer), GroupName = tolower(TargetAccount), 
GroupSid = TargetSid, AccountThatAddedUser = SubjectAccount, SIDofAccountThatAddedUser = SubjectUserSid, CreatedUserSid = MemberSid
),
(  WindowsEvent 
// 4732 - A member was added to a security-enabled local group
| where EventID == 4732 and EventData has "S-1-5-32-544"
//TargetSid is the builin Admins group: S-1-5-32-544
| extend SubjectUserSid = tostring(EventData.SubjectUserSid)
| extend AccountType=case(EventData.SubjectUserName endswith "$" or SubjectUserSid in ("S-1-5-18", "S-1-5-19", "S-1-5-20"), "Machine", isempty(SubjectUserSid), "", "User")
| where AccountType == "User"
| extend TargetSid = tostring(EventData.TargetSid)
| where TargetSid == "S-1-5-32-544"
| extend SubjectAccount = strcat(tostring(EventData.SubjectDomainName),"\\", tostring(EventData.SubjectUserName))
| extend TargetAccount = strcat(EventData.TargetDomainName,"\\", EventData.TargetUserName)
| extend Activity="4732 - A member was added to a security-enabled local group."
| extend MemberSid = tostring(EventData.MemberSid)
| project GroupAddTime = TimeGenerated, GroupAddEventID = EventID, GroupAddActivity = Activity, Computer = toupper(Computer), GroupName = tolower(TargetAccount), 
GroupSid = TargetSid, AccountThatAddedUser = SubjectAccount, SIDofAccountThatAddedUser = SubjectUserSid, CreatedUserSid = MemberSid)
))
on CreatedUserSid
//Create User first, then the add to the group.
| project Computer, CreatedUserTime, CreatedUserEventID, CreatedUserActivity, CreatedUser, CreatedUserSid, GroupAddTime, GroupAddEventID, 
GroupAddActivity, AccountUsedToCreateUser, GroupName, GroupSid, AccountThatAddedUser, SIDofAccountThatAddedUser 
| extend timestamp = CreatedUserTime, AccountCustomEntity = CreatedUser, HostCustomEntity = Computer
EOF
  entity_mapping {
    entity_type = Account
    field_mappings {
      identifier = FullName
      column_name = AccountCustomEntity
      identifier = Sid
      column_name = CreatedUserSid
    }
    entity_type = Host
    field_mappings {
      identifier = FullName
      column_name = HostCustomEntity
    }
  }
  tactics = ['Persistence', 'PrivilegeEscalation']
  techniques = ['T1078', 'T1098']
  display_name = New user created and added to the built-in administrators group
  description = <<EOT
Identifies when a user account was created and then added to the builtin Administrators group in the same day.
This should be monitored closely and all additions reviewed.
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
