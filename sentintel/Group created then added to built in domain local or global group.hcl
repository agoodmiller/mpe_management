resource "my_alert_rule" "rule_140" {
  name = "Group created then added to built in domain local or global group"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = PT1H
  query_period = PT1H
  severity = Medium
  query = <<EOF
let WellKnownLocalSID = "S-1-5-32-5[0-9][0-9]$";
let WellKnownGroupSID = "S-1-5-21-[0-9]*-[0-9]*-[0-9]*-5[0-9][0-9]$|S-1-5-21-[0-9]*-[0-9]*-[0-9]*-1102$|S-1-5-21-[0-9]*-[0-9]*-[0-9]*-1103$|S-1-5-21-[0-9]*-[0-9]*-[0-9]*-498$|S-1-5-21-[0-9]*-[0-9]*-[0-9]*-1000$";
let GroupAddition = (union isfuzzy=true   
(SecurityEvent 
// 4728 - A member was added to a security-enabled global group
// 4732 - A member was added to a security-enabled local group
// 4756 - A member was added to a security-enabled universal group  
| where EventID in ("4728", "4732", "4756") 
| where AccountType =~ "User" and MemberName == "-"
// Exclude Remote Desktop Users group: S-1-5-32-555
| where TargetSid !in ("S-1-5-32-555")
| where TargetSid matches regex WellKnownLocalSID or TargetSid matches regex WellKnownGroupSID
| project GroupAddTime = TimeGenerated, GroupAddEventID = EventID, GroupAddActivity = Activity, GroupAddComputer = Computer, GroupAddTargetAccount = TargetAccount, 
GroupAddTargetSid = TargetSid, GroupAddSubjectAccount = SubjectAccount, GroupAddSubjectUserSid = SubjectUserSid, GroupSid = MemberSid
),
(
WindowsEvent 
// 4728 - A member was added to a security-enabled global group
// 4732 - A member was added to a security-enabled local group
// 4756 - A member was added to a security-enabled universal group  
| where EventID in ("4728", "4732", "4756")  and not(EventData has "S-1-5-32-555")
| extend SubjectUserSid = tostring(EventData.SubjectUserSid)
| extend Account = strcat(tostring(EventData.SubjectDomainName),"\\", tostring(EventData.SubjectUserName))
| extend AccountType=case(Account endswith "$" or SubjectUserSid in ("S-1-5-18", "S-1-5-19", "S-1-5-20"), "Machine", isempty(SubjectUserSid), "", "User")
| extend MemberName = tostring(EventData.MemberName)
| where AccountType =~ "User" and MemberName == "-"
// Exclude Remote Desktop Users group: S-1-5-32-555
| extend TargetSid = tostring(EventData.TargetSid)
| where TargetSid !in ("S-1-5-32-555")
| where TargetSid matches regex WellKnownLocalSID or TargetSid matches regex WellKnownGroupSID
| extend TargetAccount = strcat(EventData.TargetDomainName,"\\", EventData.TargetUserName)
| extend MemberSid = tostring(EventData.MemberSid)
| extend Activity= "GroupAddActivity"
| project GroupAddTime = TimeGenerated, GroupAddEventID = EventID, GroupAddActivity = Activity, GroupAddComputer = Computer, GroupAddTargetAccount = TargetAccount, 
GroupAddTargetSid = TargetSid, GroupAddSubjectAccount = Account, GroupAddSubjectUserSid = SubjectUserSid, GroupSid = MemberSid
));
let GroupCreated = (union isfuzzy=true  
(SecurityEvent
// 4727 - A security-enabled global group was created
// 4731 - A security-enabled local group was created
// 4754 - A security-enabled universal group was created
| where EventID in ("4727", "4731", "4754")
| where AccountType =~ "User"
| project GroupCreateTime = TimeGenerated, GroupCreateEventID = EventID, GroupCreateActivity = Activity, GroupCreateComputer = Computer, GroupCreateTargetAccount = TargetAccount, 
GroupCreateSubjectAccount = SubjectAccount, GroupCreateSubjectUserSid = SubjectUserSid, GroupSid = TargetSid
),
(WindowsEvent
// 4727 - A security-enabled global group was created
// 4731 - A security-enabled local group was created
// 4754 - A security-enabled universal group was created
| where EventID in ("4727", "4731", "4754")
| extend SubjectUserSid = tostring(EventData.SubjectUserSid)
| extend Account = strcat(tostring(EventData.SubjectDomainName),"\\", tostring(EventData.SubjectUserName))
| extend AccountType=case(Account endswith "$", "Machine", iff(SubjectUserSid in ("S-1-5-18", "S-1-5-19", "S-1-5-20"), "Machine", iff(isempty(SubjectUserSid), "", "User")))
| where AccountType =~ "User"
| extend TargetAccount = strcat(EventData.TargetDomainName,"\\", EventData.TargetUserName)
| extend SubjectAccount = strcat(EventData.SubjectDomainName,"\\", EventData.SubjectUserName)  
| extend TargetSid = tostring(EventData.TargetSid) 
| extend Activity= "GroupAddActivity"
| project GroupCreateTime = TimeGenerated, GroupCreateEventID = EventID, GroupCreateActivity = Activity, GroupCreateComputer = Computer, GroupCreateTargetAccount = TargetAccount, 
GroupCreateSubjectAccount = SubjectAccount, GroupCreateSubjectUserSid = SubjectUserSid, GroupSid = TargetSid
));
GroupCreated
| join (
GroupAddition
) on GroupSid 
| extend timestamp = GroupCreateTime, AccountCustomEntity = GroupCreateSubjectAccount, HostCustomEntity = GroupCreateComputer
EOF
  entity_mapping {
    entity_type = Account
    field_mappings {
      identifier = FullName
      column_name = AccountCustomEntity
      identifier = Sid
      column_name = GroupCreateSubjectUserSid
    }
    entity_type = Host
    field_mappings {
      identifier = FullName
      column_name = HostCustomEntity
    }
  }
  tactics = ['Persistence', 'PrivilegeEscalation']
  techniques = ['T1078', 'T1098']
  display_name = Group created then added to built in domain local or global group
  description = <<EOT
Identifies when a recently created Group was added to a privileged built in domain local group or global group such as the 
Enterprise Admins, Cert Publishers or DnsAdmins.  Be sure to verify this is an expected addition.
References: For AD SID mappings - https://docs.microsoft.com/windows/security/identity-protection/access-control/active-directory-security-groups.
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
