resource "my_alert_rule" "rule_267" {
  name = "Powershell Empire cmdlets seen in command line"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = PT12H
  query_period = PT12H
  severity = Medium
  query = <<EOF
let regexEmpire = @"SetDelay|GetDelay|Set-LostLimit|Get-LostLimit|Set-Killdate|Get-Killdate|Set-WorkingHours|Get-WorkingHours|Get-Sysinfo|Add-Servers|Invoke-ShellCommand|Start-AgentJob|Update-Profile|Get-FilePart|Encrypt-Bytes|Decrypt-Bytes|Encode-Packet|Decode-Packet|Send-Message|Process-Packet|Process-Tasking|Get-Task|Start-Negotiate|Invoke-DllInjection|Invoke-ReflectivePEInjection|Invoke-Shellcode|Invoke-ShellcodeMSIL|Get-ChromeDump|Get-ClipboardContents|Get-IndexedItem|Get-Keystrokes|Invoke-Inveigh|Invoke-NetRipper|local:Invoke-PatchDll|Invoke-NinjaCopy|Get-Win32Types|Get-Win32Constants|Get-Win32Functions|Sub-SignedIntAsUnsigned|Add-SignedIntAsUnsigned|Compare-Val1GreaterThanVal2AsUInt|Convert-UIntToInt|Test-MemoryRangeValid|Write-BytesToMemory|Get-DelegateType|Get-ProcAddress|Enable-SeDebugPrivilege|Invoke-CreateRemoteThread|Get-ImageNtHeaders|Get-PEBasicInfo|Get-PEDetailedInfo|Import-DllInRemoteProcess|Get-RemoteProcAddress|Copy-Sections|Update-MemoryAddresses|Import-DllImports|Get-VirtualProtectValue|Update-MemoryProtectionFlags|Update-ExeFunctions|Copy-ArrayOfMemAddresses|Get-MemoryProcAddress|Invoke-MemoryLoadLibrary|Invoke-MemoryFreeLibrary|Out-Minidump|Get-VaultCredential|Invoke-DCSync|Translate-Name|Get-NetDomain|Get-NetForest|Get-NetForestDomain|Get-DomainSearcher|Get-NetComputer|Get-NetGroupMember|Get-NetUser|Invoke-Mimikatz|Invoke-PowerDump|Invoke-TokenManipulation|Exploit-JMXConsole|Exploit-JBoss|Invoke-Thunderstruck|Invoke-VoiceTroll|Set-WallPaper|Invoke-PsExec|Invoke-SSHCommand|Invoke-PSInject|Invoke-RunAs|Invoke-SendMail|Invoke-Rule|Get-OSVersion|Select-EmailItem|View-Email|Get-OutlookFolder|Get-EmailItems|Invoke-MailSearch|Get-SubFolders|Get-GlobalAddressList|Invoke-SearchGAL|Get-SMTPAddress|Disable-SecuritySettings|Reset-SecuritySettings|Get-OutlookInstance|New-HoneyHash|Set-MacAttribute|Invoke-PatchDll|Get-SecurityPackages|Install-SSP|Invoke-BackdoorLNK|New-ElevatedPersistenceOption|New-UserPersistenceOption|Add-Persistence|Invoke-CallbackIEX|Add-PSFirewallRules|Invoke-EventLoop|Invoke-PortBind|Invoke-DNSLoop|Invoke-PacketKnock|Invoke-CallbackLoop|Invoke-BypassUAC|Get-DecryptedCpassword|Get-GPPInnerFields|Invoke-WScriptBypassUAC|Get-ModifiableFile|Get-ServiceUnquoted|Get-ServiceFilePermission|Get-ServicePermission|Invoke-ServiceUserAdd|Invoke-ServiceCMD|Write-UserAddServiceBinary|Write-CMDServiceBinary|Write-ServiceEXE|Write-ServiceEXECMD|Restore-ServiceEXE|Invoke-ServiceStart|Invoke-ServiceStop|Invoke-ServiceEnable|Invoke-ServiceDisable|Get-ServiceDetail|Find-DLLHijack|Find-PathHijack|Write-HijackDll|Get-RegAlwaysInstallElevated|Get-RegAutoLogon|Get-VulnAutoRun|Get-VulnSchTask|Get-UnattendedInstallFile|Get-Webconfig|Get-ApplicationHost|Write-UserAddMSI|Invoke-AllChecks|Invoke-ThreadedFunction|Test-Login|Get-UserAgent|Test-Password|Get-ComputerDetails|Find-4648Logons|Find-4624Logons|Find-AppLockerLogs|Find-PSScriptsInPSAppLog|Find-RDPClientConnections|Get-SystemDNSServer|Invoke-Paranoia|Invoke-WinEnum{|Get-SPN|Invoke-ARPScan|Invoke-Portscan|Invoke-ReverseDNSLookup|Invoke-SMBScanner|New-InMemoryModule|Add-Win32Type|Export-PowerViewCSV|Get-MacAttribute|Copy-ClonedFile|Get-IPAddress|Convert-NameToSid|Convert-SidToName|Convert-NT4toCanonical|Get-Proxy|Get-PathAcl|Get-NameField|Convert-LDAPProperty|Get-NetDomainController|Add-NetUser|Add-NetGroupUser|Get-UserProperty|Find-UserField|Get-UserEvent|Get-ObjectAcl|Add-ObjectAcl|Invoke-ACLScanner|Get-GUIDMap|Get-ADObject|Set-ADObject|Get-ComputerProperty|Find-ComputerField|Get-NetOU|Get-NetSite|Get-NetSubnet|Get-DomainSID|Get-NetGroup|Get-NetFileServer|SplitPath|Get-DFSshare|Get-DFSshareV1|Get-DFSshareV2|Get-GptTmpl|Get-GroupsXML|Get-NetGPO|Get-NetGPOGroup|Find-GPOLocation|Find-GPOComputerAdmin|Get-DomainPolicy|Get-NetLocalGroup|Get-NetShare|Get-NetLoggedon|Get-NetSession|Get-NetRDPSession|Invoke-CheckLocalAdminAccess|Get-LastLoggedOn|Get-NetProcess|Find-InterestingFile|Invoke-CheckWrite|Invoke-UserHunter|Invoke-StealthUserHunter|Invoke-ProcessHunter|Invoke-EventHunter|Invoke-ShareFinder|Invoke-FileFinder|Find-LocalAdminAccess|Get-ExploitableSystem|Invoke-EnumerateLocalAdmin|Get-NetDomainTrust|Get-NetForestTrust|Find-ForeignUser|Find-ForeignGroup|Invoke-MapDomainTrust|Get-Hex|Create-RemoteThread|Get-FoxDump|Decrypt-CipherText|Get-Screenshot|Start-HTTP-Server|Local:Invoke-CreateRemoteThread|Local:Get-Win32Functions|Local:Inject-NetRipper|GetCommandLine|ElevatePrivs|Get-RegKeyClass|Get-BootKey|Get-HBootKey|Get-UserName|Get-UserHashes|DecryptHashes|DecryptSingleHash|Get-UserKeys|DumpHashes|Enable-SeAssignPrimaryTokenPrivilege|Enable-Privilege|Set-DesktopACLs|Set-DesktopACLToAllowEveryone|Get-PrimaryToken|Get-ThreadToken|Get-TokenInformation|Get-UniqueTokens|Find-GPOLocation|Find-GPOComputerAdmin|Get-DomainPolicy|Get-NetLocalGroup|Get-NetShare|Get-NetLoggedon|Get-NetSession|Get-NetRDPSession|Invoke-CheckLocalAdminAccess|Get-LastLoggedOn|Get-NetProcess|Find-InterestingFile|Invoke-CheckWrite|Invoke-UserHunter|Invoke-StealthUserHunter|Invoke-ProcessHunter|Invoke-EventHunter|Invoke-ShareFinder|Invoke-FileFinder|Find-LocalAdminAccess|Get-ExploitableSystem|Invoke-EnumerateLocalAdmin|Get-NetDomainTrust|Get-NetForestTrust|Find-ForeignUser|Find-ForeignGroup|Invoke-MapDomainTrust|Get-Hex|Create-RemoteThread|Get-FoxDump|Decrypt-CipherText|Get-Screenshot|Start-HTTP-Server|Local:Invoke-CreateRemoteThread|Local:Get-Win32Functions|Local:Inject-NetRipper|GetCommandLine|ElevatePrivs|Get-RegKeyClass|Get-BootKey|Get-HBootKey|Get-UserName|Get-UserHashes|DecryptHashes|DecryptSingleHash|Get-UserKeys|DumpHashes|Enable-SeAssignPrimaryTokenPrivilege|Enable-Privilege|Set-DesktopACLs|Set-DesktopACLToAllowEveryone|Get-PrimaryToken|Get-ThreadToken|Get-TokenInformation|Get-UniqueTokens|Invoke-ImpersonateUser|Create-ProcessWithToken|Free-AllTokens|Enum-AllTokens|Invoke-RevertToSelf|Set-Speaker\(\$Volume\){\$wshShell|Local:Get-RandomString|Local:Invoke-PsExecCmd|Get-GPPPassword|Local:Inject-BypassStuff|Local:Invoke-CopyFile\(\$sSource,|ind-Fruit|New-IPv4Range|New-IPv4RangeFromCIDR|Parse-Hosts|Parse-ILHosts|Exclude-Hosts|Get-TopPort|Parse-Ports|Parse-IpPorts|Remove-Ports|Write-PortscanOut|Convert-SwitchtoBool|Get-ForeignUser|Get-ForeignGroup";
(union isfuzzy=true
 (SecurityEvent
| where EventID == 4688
//consider filtering on filename if perf issues occur
//where FileName in~ ("powershell.exe","powershell_ise.exe","pwsh.exe")
| where not(ParentProcessName has_any ('gc_worker.exe', 'gc_service.exe'))
| where CommandLine has "-encodedCommand"
| parse kind=regex flags=i CommandLine with * "-EncodedCommand " encodedCommand
| extend encodedCommand = iff(encodedCommand has " ", tostring(split(encodedCommand, " ")[0]), encodedCommand)
// Note: currently the base64_decode_tostring function is limited to supporting UTF8
| extend decodedCommand = translate('\0','', base64_decode_tostring(substring(encodedCommand, 0, strlen(encodedCommand) -  (strlen(encodedCommand) %8)))), encodedCommand, CommandLine , strlen(encodedCommand)
| extend EfectiveCommand = iff(isnotempty(encodedCommand), decodedCommand, CommandLine)
| where EfectiveCommand matches regex regexEmpire
| project TimeGenerated, Computer, Account = SubjectUserName, AccountDomain = SubjectDomainName, FileName = Process, EfectiveCommand, decodedCommand, encodedCommand, CommandLine, ParentProcessName
| extend timestamp = TimeGenerated, AccountCustomEntity = Account, HostCustomEntity = Computer
),
(WindowsEvent
| where EventID == 4688 
| where EventData has_any ("-encodedCommand", "powershell.exe","powershell_ise.exe","pwsh.exe")
| where not(EventData has_any ('gc_worker.exe', 'gc_service.exe'))
//consider filtering on filename if perf issues occur
//extend NewProcessName = tostring(EventData.NewProcessName)
//extend Process=tostring(split(NewProcessName, '\\')[-1])
//FileName = Process
//where FileName in~ ("powershell.exe","powershell_ise.exe","pwsh.exe")
| extend ParentProcessName = tostring(EventData.ParentProcessName)
| where not(ParentProcessName has_any ('gc_worker.exe', 'gc_service.exe'))
| extend CommandLine = tostring(EventData.CommandLine)
| where CommandLine has "-encodedCommand"
| parse kind=regex flags=i CommandLine with * "-EncodedCommand " encodedCommand
| extend encodedCommand = iff(encodedCommand has " ", tostring(split(encodedCommand, " ")[0]), encodedCommand)
// Note: currently the base64_decode_tostring function is limited to supporting UTF8
| extend decodedCommand = translate('\0','', base64_decode_tostring(substring(encodedCommand, 0, strlen(encodedCommand) -  (strlen(encodedCommand) %8)))), encodedCommand, CommandLine , strlen(encodedCommand)
| extend EfectiveCommand = iff(isnotempty(encodedCommand), decodedCommand, CommandLine)
| where EfectiveCommand matches regex regexEmpire
| extend SubjectUserName = tostring(EventData.SubjectUserName)
| extend SubjectDomainName = tostring(EventData.SubjectDomainName)
| extend NewProcessName = tostring(EventData.NewProcessName)
| extend Process=tostring(split(NewProcessName, '\\')[-1])
| project TimeGenerated, Computer, Account = SubjectUserName, AccountDomain = SubjectDomainName, FileName = Process, EfectiveCommand, decodedCommand, encodedCommand, CommandLine, ParentProcessName
| extend timestamp = TimeGenerated, AccountCustomEntity = Account, HostCustomEntity = Computer
))
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
  tactics = ['Execution', 'Persistence']
  techniques = ['T1059', 'T1546']
  display_name = Powershell Empire cmdlets seen in command line
  description = <<EOT
Identifies instances of PowerShell Empire cmdlets in powershell process command line data.
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
