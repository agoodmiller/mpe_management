resource "my_alert_rule" "rule_189" {
  name = "User account added to built in domain local or global group"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P1D
  severity = Low
  query = <<EOF
// For AD SID mappings - https://docs.microsoft.com/windows/security/identity-protection/access-control/active-directory-security-groups
let WellKnownLocalSID = "S-1-5-32-5[0-9][0-9]$";
let WellKnownGroupSID = "S-1-5-21-[0-9]*-[0-9]*-[0-9]*-5[0-9][0-9]$|S-1-5-21-[0-9]*-[0-9]*-[0-9]*-1102$|S-1-5-21-[0-9]*-[0-9]*-[0-9]*-1103$|S-1-5-21-[0-9]*-[0-9]*-[0-9]*-498$|S-1-5-21-[0-9]*-[0-9]*-[0-9]*-1000$";
union isfuzzy=true 
(
SecurityEvent 
// When MemberName contains '-' this indicates addition of a group to a group
| where AccountType == "User" and MemberName != "-"
// 4728 - A member was added to a security-enabled global group
// 4732 - A member was added to a security-enabled local group
// 4756 - A member was added to a security-enabled universal group
| where EventID in (4728, 4732, 4756)   
| where TargetSid matches regex WellKnownLocalSID or TargetSid matches regex WellKnownGroupSID
// Exclude Remote Desktop Users group: S-1-5-32-555
| where TargetSid !in ("S-1-5-32-555")
| extend SimpleMemberName = substring(MemberName, 3, indexof_regex(MemberName, @",OU|,CN") - 3)
| project TimeGenerated, EventID, Activity, Computer, SimpleMemberName, MemberName, MemberSid, TargetUserName, TargetDomainName, TargetSid, UserPrincipalName, SubjectUserName, SubjectUserSid
| extend timestamp = TimeGenerated, AccountCustomEntity = SimpleMemberName, HostCustomEntity = Computer
),
(
WindowsEvent 
// 4728 - A member was added to a security-enabled global group
// 4732 - A member was added to a security-enabled local group
// 4756 - A member was added to a security-enabled universal group
| where EventID in (4728, 4732, 4756)  and  not(EventData has "S-1-5-32-555")
| extend SubjectUserSid = tostring(EventData.SubjectUserSid)
| extend Account =  strcat(tostring(EventData.SubjectDomainName),"\\", tostring(EventData.SubjectUserName))
| extend AccountType=case(Account endswith "$" or SubjectUserSid in ("S-1-5-18", "S-1-5-19", "S-1-5-20"), "Machine", isempty(SubjectUserSid), "", "User")
| extend MemberName = tostring(EventData.MemberName)
// When MemberName contains '-' this indicates addition of a group to a group
| where AccountType == "User" and MemberName != "-"
| extend TargetSid = tostring(EventData.TargetSid)
| where TargetSid matches regex WellKnownLocalSID or TargetSid matches regex WellKnownGroupSID
// Exclude Remote Desktop Users group: S-1-5-32-555
| where TargetSid !in ("S-1-5-32-555")
| extend SimpleMemberName = substring(MemberName, 3, indexof_regex(MemberName, @",OU|,CN") - 3)
| extend MemberSid = tostring(EventData.MemberSid)
| extend TargetUserName = tostring(EventData.TargetUserName)
| extend TargetDomainName = tostring(EventData.TargetDomainName)
| extend UserPrincipalName = tostring(EventData.UserPrincipalName)
| extend SubjectUserName = tostring(EventData.SubjectUserName)
| project TimeGenerated, EventID, Computer, SimpleMemberName, MemberName, MemberSid, TargetUserName, TargetDomainName, TargetSid, UserPrincipalName, SubjectUserName, SubjectUserSid
| extend timestamp = TimeGenerated, AccountCustomEntity = SimpleMemberName, HostCustomEntity = Computer
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
  tactics = ['Persistence', 'PrivilegeEscalation']
  techniques = ['T1078', 'T1098']
  display_name = User account added to built in domain local or global group
  description = <<EOT
Identifies when a user account has been added to a privileged built in domain local group or global group 
such as the Enterprise Admins, Cert Publishers or DnsAdmins. Be sure to verify this is an expected addition.
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
