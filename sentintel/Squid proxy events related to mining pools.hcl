resource "my_alert_rule" "rule_136" {
  name = "Squid proxy events related to mining pools"
  log_analytics_workspace_id = var.client_log_analytics_workspace_id
  query_frequency = P1D
  query_period = P1D
  severity = Low
  query = <<EOF
let DomainList = dynamic(["monerohash.com", "do-dear.com", "xmrminerpro.com", "secumine.net", "xmrpool.com", "minexmr.org", "hashanywhere.com", "xmrget.com", 
"mininglottery.eu", "minergate.com", "moriaxmr.com", "multipooler.com", "moneropools.com", "xmrpool.eu", "coolmining.club", "supportxmr.com",
"minexmr.com", "hashvault.pro", "xmrpool.net", "crypto-pool.fr", "xmr.pt", "miner.rocks", "walpool.com", "herominers.com", "gntl.co.uk", "semipool.com", 
"coinfoundry.org", "cryptoknight.cc", "fairhash.org", "baikalmine.com", "tubepool.xyz", "fairpool.xyz", "asiapool.io", "coinpoolit.webhop.me", "nanopool.org", 
"moneropool.com", "miner.center", "prohash.net", "poolto.be", "cryptoescrow.eu", "monerominers.net", "cryptonotepool.org", "extrmepool.org", "webcoin.me", 
"kippo.eu", "hashinvest.ws", "monero.farm", "supportxmr.com", "xmrpool.eu", "linux-repository-updates.com", "1gh.com", "dwarfpool.com", "hash-to-coins.com", 
"hashvault.pro", "pool-proxy.com", "hashfor.cash", "fairpool.cloud", "litecoinpool.org", "mineshaft.ml", "abcxyz.stream", "moneropool.ru", "cryptonotepool.org.uk",
"extremepool.org", "extremehash.com", "hashinvest.net", "unipool.pro", "crypto-pools.org", "monero.net", "backup-pool.com", "mooo.com", "freeyy.me", "cryptonight.net",
"shscrypto.net"]);
Syslog
| where ProcessName contains "squid"
| extend URL = extract("(([A-Z]+ [a-z]{4,5}:\\/\\/)|[A-Z]+ )([^ :]*)",3,SyslogMessage), 
        SourceIP = extract("([0-9]+ )(([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3}))",2,SyslogMessage), 
        Status = extract("(TCP_(([A-Z]+)(_[A-Z]+)*)|UDP_(([A-Z]+)(_[A-Z]+)*))",1,SyslogMessage), 
        HTTP_Status_Code = extract("(TCP_(([A-Z]+)(_[A-Z]+)*)|UDP_(([A-Z]+)(_[A-Z]+)*))/([0-9]{3})",8,SyslogMessage),
        User = extract("(CONNECT |GET )([^ ]* )([^ ]+)",3,SyslogMessage),
        RemotePort = extract("(CONNECT |GET )([^ ]*)(:)([0-9]*)",4,SyslogMessage),
        Domain = extract("(([A-Z]+ [a-z]{4,5}:\\/\\/)|[A-Z]+ )([^ :\\/]*)",3,SyslogMessage),
        Bytes = toint(extract("([A-Z]+\\/[0-9]{3} )([0-9]+)",2,SyslogMessage)),
        contentType = extract("([a-z/]+$)",1,SyslogMessage)
| extend TLD = extract("\\.[a-z]*$",0,Domain)
| where HTTP_Status_Code == '200'
| where Domain contains "."
| where Domain has_any (DomainList)
| extend timestamp = TimeGenerated, URLCustomEntity = URL, IPCustomEntity = SourceIP, AccountCustomEntity = User
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
    entity_type = URL
    field_mappings {
      identifier = Url
      column_name = URLCustomEntity
    }
  }
  tactics = ['CommandAndControl']
  techniques = ['T1102']
  display_name = Squid proxy events related to mining pools
  description = <<EOT
Checks for Squid proxy events in Syslog associated with common mining pools .This query presumes the default Squid log format is being used. 
 http://www.squid-cache.org/Doc/config/access_log/
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
