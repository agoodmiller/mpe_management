resource "my_alert_rule" "rule_96" {
  name = "High count of failed logons by a user"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P1D
  severity = Medium
  query = <<EOF
let timeBin = 10m;
let failedThreshold = 100;
W3CIISLog
| where scStatus in ("401","403")
| where csUserName != "-"
// Handling Exchange specific items in IIS logs to remove the unique log identifier in the URI
| extend csUriQuery = iff(csUriQuery startswith "MailboxId=", tostring(split(csUriQuery, "&")[0]) , csUriQuery )
| extend csUriQuery = iff(csUriQuery startswith "X-ARR-CACHE-HIT=", strcat(tostring(split(csUriQuery, "&")[0]),tostring(split(csUriQuery, "&")[1])) , csUriQuery )
| extend scStatusFull = strcat(scStatus, ".",scSubStatus) 
// Map common IIS codes
| extend scStatusFull_Friendly = case(
scStatusFull == "401.0", "Access denied.",
scStatusFull == "401.1", "Logon failed.",
scStatusFull == "401.2", "Logon failed due to server configuration.",
scStatusFull == "401.3", "Unauthorized due to ACL on resource.",
scStatusFull == "401.4", "Authorization failed by filter.",
scStatusFull == "401.5", "Authorization failed by ISAPI/CGI application.",
scStatusFull == "403.0", "Forbidden.",
scStatusFull == "403.4", "SSL required.",
"See - https://support.microsoft.com/help/943891/the-http-status-code-in-iis-7-0-iis-7-5-and-iis-8-0")
// Mapping to Hex so can be mapped using website in comments above
| extend scWin32Status_Hex = tohex(tolong(scWin32Status)) 
// Map common win32 codes
| extend scWin32Status_Friendly = case(
scWin32Status_Hex =~ "775", "The referenced account is currently locked out and cannot be logged on to.",
scWin32Status_Hex =~ "52e", "Logon failure: Unknown user name or bad password.",
scWin32Status_Hex =~ "532", "Logon failure: The specified account password has expired.",
scWin32Status_Hex =~ "533", "Logon failure: Account currently disabled.", 
scWin32Status_Hex =~ "2ee2", "The request has timed out.", 
scWin32Status_Hex =~ "0", "The operation completed successfully.", 
scWin32Status_Hex =~ "1", "Incorrect function.", 
scWin32Status_Hex =~ "2", "The system cannot find the file specified.", 
scWin32Status_Hex =~ "3", "The system cannot find the path specified.", 
scWin32Status_Hex =~ "4", "The system cannot open the file.", 
scWin32Status_Hex =~ "5", "Access is denied.", 
scWin32Status_Hex =~ "8009030e", "SEC_E_NO_CREDENTIALS", 
scWin32Status_Hex =~ "8009030C", "SEC_E_LOGON_DENIED", 
"See - https://msdn.microsoft.com/library/cc231199.aspx")
// decode URI when available
| extend decodedUriQuery = url_decode(csUriQuery)
// Count of failed logons by a user
| summarize makeset(decodedUriQuery), makeset(cIP), makeset(sSiteName), makeset(sPort), makeset(csUserAgent), makeset(csMethod), makeset(csUriQuery), makeset(scStatusFull), makeset(scStatusFull_Friendly), makeset(scWin32Status_Hex), makeset(scWin32Status_Friendly), FailedConnectionsCount = count() by bin(TimeGenerated, timeBin), csUserName, Computer, sIP
| where FailedConnectionsCount >= failedThreshold
| project TimeGenerated, csUserName, set_decodedUriQuery, Computer, set_sSiteName, sIP, set_cIP, set_sPort, set_csUserAgent, set_csMethod, set_scStatusFull, set_scStatusFull_Friendly, set_scWin32Status_Hex, set_scWin32Status_Friendly, FailedConnectionsCount
| order by FailedConnectionsCount
| extend timestamp = TimeGenerated, AccountCustomEntity = csUserName, HostCustomEntity = Computer
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
  tactics = ['CredentialAccess']
  techniques = ['T1110']
  display_name = High count of failed logons by a user
  description = <<EOT
Identifies when 100 or more failed attempts by a given user in 10 minutes occur on the IIS Server.
This could be indicative of attempted brute force based on known account information.
This could also simply indicate a misconfigured service or device. 
References:
IIS status code mapping - https://support.microsoft.com/help/943891/the-http-status-code-in-iis-7-0-iis-7-5-and-iis-8-0
Win32 Status code mapping - https://msdn.microsoft.com/library/cc231199.aspx
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
