resource "my_alert_rule" "rule_134" {
  name = "Password spray attack against Azure AD application"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P7D
  severity = Medium
  query = <<EOF
let timeRange = 3d;
let lookBack = 7d;
let authenticationWindow = 20m;
let authenticationThreshold = 5;
let isGUID = "[0-9a-z]{8}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{12}";
let failureCodes = dynamic([50053, 50126, 50055]); // invalid password, account is locked - too many sign ins, expired password
let successCodes = dynamic([0, 50055, 50057, 50155, 50105, 50133, 50005, 50076, 50079, 50173, 50158, 50072, 50074, 53003, 53000, 53001, 50129]);
// Lookup up resolved identities from last 7 days
let aadFunc = (tableName:string){
let identityLookup = table(tableName)
| where TimeGenerated >= ago(lookBack)
| where not(Identity matches regex isGUID)
| where isnotempty(UserId)
| summarize by UserId, lu_UserDisplayName = UserDisplayName, lu_UserPrincipalName = UserPrincipalName, Type;
// collect window threshold breaches
table(tableName)
| where TimeGenerated > ago(timeRange)
| where ResultType in(failureCodes)
| summarize StartTime = min(TimeGenerated), EndTime = max(TimeGenerated), make_set(ClientAppUsed), count() by bin(TimeGenerated, authenticationWindow), IPAddress, AppDisplayName, UserPrincipalName, Type
| summarize FailedPrincipalCount = dcount(UserPrincipalName) by bin(TimeGenerated, authenticationWindow), IPAddress, AppDisplayName, Type
| where FailedPrincipalCount >= authenticationThreshold
| summarize WindowThresholdBreaches = count() by IPAddress, Type
| join kind= inner (
// where we breached a threshold, join the details back on all failure data
table(tableName)
| where TimeGenerated > ago(timeRange)
| where ResultType in(failureCodes)
| extend LocationDetails = todynamic(LocationDetails)
| extend FullLocation = strcat(LocationDetails.countryOrRegion,'|', LocationDetails.state, '|', LocationDetails.city)
| summarize StartTime = min(TimeGenerated), EndTime = max(TimeGenerated), make_set(ClientAppUsed), make_set(FullLocation), FailureCount = count() by IPAddress, AppDisplayName, UserPrincipalName, UserDisplayName, Identity, UserId, Type
// lookup any unresolved identities
| extend UnresolvedUserId = iff(Identity matches regex isGUID, UserId, "")
| join kind= leftouter (
 identityLookup 
) on $left.UnresolvedUserId==$right.UserId
| extend UserDisplayName=iff(isempty(lu_UserDisplayName), UserDisplayName, lu_UserDisplayName)
| extend UserPrincipalName=iff(isempty(lu_UserPrincipalName), UserPrincipalName, lu_UserPrincipalName)
| summarize StartTime = min(StartTime), EndTime = max(EndTime), make_set(UserPrincipalName), make_set(UserDisplayName), make_set(set_ClientAppUsed), make_set(set_FullLocation), make_list(FailureCount) by IPAddress, AppDisplayName, Type
| extend FailedPrincipalCount = arraylength(set_UserPrincipalName)
) on IPAddress
| project IPAddress, StartTime, EndTime, TargetedApplication=AppDisplayName, FailedPrincipalCount, UserPrincipalNames=set_UserPrincipalName, UserDisplayNames=set_UserDisplayName, ClientAppsUsed=set_set_ClientAppUsed, Locations=set_set_FullLocation, FailureCountByPrincipal=list_FailureCount, WindowThresholdBreaches, Type
| join kind= inner (
table(tableName) // get data on success vs. failure history for each IP
| where TimeGenerated > ago(timeRange)
| where ResultType in(successCodes) or ResultType in(failureCodes) // success or failure types
| summarize GlobalSuccessPrincipalCount = dcountif(UserPrincipalName, (ResultType in(successCodes))), ResultTypeSuccesses = make_set_if(ResultType, (ResultType in(successCodes))), GlobalFailPrincipalCount = dcountif(UserPrincipalName, (ResultType in(failureCodes))), ResultTypeFailures = make_set_if(ResultType, (ResultType in(failureCodes))) by IPAddress, Type
| where GlobalFailPrincipalCount > GlobalSuccessPrincipalCount // where the number of failed principals is greater than success - eliminates FPs from IPs who authenticate successfully alot and as a side effect have alot of failures
) on IPAddress
| project-away IPAddress1
| extend timestamp=StartTime, IPCustomEntity = IPAddress
};
let aadSignin = aadFunc("SigninLogs");
let aadNonInt = aadFunc("AADNonInteractiveUserSignInLogs");
union isfuzzy=true aadSignin, aadNonInt
EOF
  entity_mapping {
    entity_type = IP
    field_mappings {
      identifier = Address
      column_name = IPCustomEntity
    }
  }
  tactics = ['CredentialAccess']
  techniques = ['T1110']
  display_name = Password spray attack against Azure AD application
  description = <<EOT
Identifies evidence of password spray activity against Azure AD applications by looking for failures from multiple accounts from the same
IP address within a time window. If the number of accounts breaches the threshold just once, all failures from the IP address within the time range
are bought into the result. Details on whether there were successful authentications by the IP address within the time window are also included.
This can be an indicator that an attack was successful.
The default failure acccount threshold is 5, Default time window for failures is 20m and default look back window is 3 days
Note: Due to the number of possible accounts involved in a password spray it is not possible to map identities to a custom entity.
References: https://docs.microsoft.com/azure/active-directory/reports-monitoring/reference-sign-ins-error-codes.
EOT
  enabled = False
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
