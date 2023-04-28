resource "my_alert_rule" "rule_285" {
  name = "High count of connections by client IP on many ports"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P1D
  severity = Medium
  query = <<EOF
let timeBin = 10m;
let portThreshold = 30;
W3CIISLog
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
// Count of attempts by client IP on many ports
| summarize makeset(sPort), makeset(decodedUriQuery), makeset(csUserName), makeset(sSiteName), makeset(sPort), makeset(csUserAgent), makeset(csMethod), makeset(csUriQuery), makeset(scStatusFull), makeset(scStatusFull_Friendly), makeset(scWin32Status_Hex), makeset(scWin32Status_Friendly), ConnectionsCount = count() by bin(TimeGenerated, timeBin), cIP, Computer, sIP
| extend portCount = arraylength(set_sPort)
| where portCount >= portThreshold
| project TimeGenerated, cIP, set_sPort, set_csUserName, set_decodedUriQuery, Computer, set_sSiteName, sIP, set_csUserAgent, set_csMethod, set_scStatusFull, set_scStatusFull_Friendly, set_scWin32Status_Hex, set_scWin32Status_Friendly, ConnectionsCount, portCount
| order by portCount
| extend timestamp = TimeGenerated, IPCustomEntity = cIP
EOF
  entity_mapping {
    entity_type = IP
    field_mappings {
      identifier = Address
      column_name = IPCustomEntity
    }
  }
  tactics = ['InitialAccess']
  techniques = ['T1190']
  display_name = High count of connections by client IP on many ports
  description = <<EOT
Identifies when 30 or more ports are used for a given client IP in 10 minutes occurring on the IIS server.
This could be indicative of attempted port scanning or exploit attempt at internet facing web applications.  
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
