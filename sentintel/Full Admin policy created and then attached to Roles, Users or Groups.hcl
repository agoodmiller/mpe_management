resource "my_alert_rule" "rule_138" {
  name = "Full Admin policy created and then attached to Roles, Users or Groups"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P14D
  severity = Medium
  query = <<EOF
let EventNameList = dynamic(["AttachUserPolicy","AttachRolePolicy","AttachGroupPolicy"]);
let createPolicy = "CreatePolicy";
let timeframe = 1d;
let lookback = 14d;
// Creating Master table with all the events to use with materialize for better performance
let EventInfo = AWSCloudTrail
| where TimeGenerated >= ago(lookback)
| where EventName in (EventNameList) or EventName == createPolicy;
//Checking for Policy creation event with Full Admin Privileges since lookback period.
let FullAdminPolicyEvents =  materialize(  EventInfo
| where TimeGenerated >= ago(lookback)
| where EventName == createPolicy
| extend PolicyName = tostring(parse_json(RequestParameters).policyName)
| extend Statement = parse_json(tostring((parse_json(RequestParameters).policyDocument))).Statement
| mvexpand Statement
| extend Action = parse_json(Statement).Action , Effect = tostring(parse_json(Statement).Effect), Resource = tostring(parse_json(Statement).Resource)
| mvexpand Action
| extend Action = tostring(Action)
| where Effect =~ "Allow" and Action == "*" and Resource == "*"
| distinct TimeGenerated, EventName, PolicyName, SourceIpAddress, UserIdentityArn, UserIdentityUserName
| extend UserIdentityUserName = iff(isnotempty(UserIdentityUserName), UserIdentityUserName, tostring(split(UserIdentityArn,'/')[-1]))
| project-rename StartTime = TimeGenerated  );
let PolicyAttach = materialize(  EventInfo
| where TimeGenerated >= ago(timeframe)
| where EventName in (EventNameList)
| extend PolicyName = tostring(split(tostring(parse_json(RequestParameters).policyArn),"/")[1])
| summarize AttachEventCount=count(), StartTime = min(TimeGenerated), EndTime = max(TimeGenerated) by EventSource, EventName,   UserIdentityType , UserIdentityArn, SourceIpAddress, UserIdentityUserName = iff(isnotempty(UserIdentityUserName),   UserIdentityUserName, tostring(split(UserIdentityArn,'/')[-1])), PolicyName
| extend AttachEvent = pack("StartTime", StartTime, "EndTime", EndTime, "EventName", EventName, "UserIdentityType",   UserIdentityType, "UserIdentityArn", UserIdentityArn, "SourceIpAddress", SourceIpAddress, "UserIdentityUserName", UserIdentityUserName)
| project EventSource, PolicyName, AttachEvent, AttachEventCount
);
// Joining the list of PolicyNames and checking if it has been attached to any Roles/Users/Groups.
// These Roles/Users/Groups will be Privileged and can be used by adversaries as pivot point for privilege escalation via multiple ways.
FullAdminPolicyEvents
| join kind=leftouter
(
    PolicyAttach
)
on PolicyName
| project-away PolicyName1
| extend timestamp = StartTime, IPCustomEntity = SourceIpAddress, AccountCustomEntity = UserIdentityUserName
EOF
  entity_mapping {
    entity_type = Account
    field_mappings {
      identifier = FullName
      column_name = AccountCustomEntity
    }
    entity_type = IP
    field_mappings {
      identifier = Address
      column_name = IPCustomEntity
    }
  }
  tactics = ['PrivilegeEscalation']
  techniques = ['T1134']
  display_name = Full Admin policy created and then attached to Roles, Users or Groups
  description = <<EOT
Identity and Access Management (IAM) securely manages access to AWS services and resources. 
Identifies when a policy is created with Full Administrators Access (Allow-Action:*,Resource:*). 
This policy can be attached to role,user or group and may be used by an adversary to escalate a normal user privileges to an adminsitrative level.
AWS IAM Policy Grammar: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_grammar.html
and AWS IAM API at https://docs.aws.amazon.com/IAM/latest/APIReference/API_Operations.html
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
