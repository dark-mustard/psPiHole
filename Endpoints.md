# PiHole API
## Endpoints
A list of API endpoints can be found by running the following command on the PiHole server:
```bash
find /var/www/html/admin -name "api*.php"
```

| Endpoint      | Accessibility | Notes |
|:--------------|:-------------:|:------|
| `api.php`     | Active        | Primary endpoint for API requests. |
| `api_FTL.php` | Inactive      | Contains back-end functions passed through from `api.php`. **Not to be called directly.** |
| `api_db.php`  | Deprecated    | Contains a mix of back-end functions and unique and directly accessible functions. |
 
## API Methods
The following was derived by reading through the endpoint php files listed above...just a first pass so most likely several that are wrong / missing.
- [x] Get Host Info
  - [x] Get Version
    - [x] GET http://`$PiHoleHost`/admin/api.php?version
    - [x] GET http://`$PiHoleHost`/admin/api.php?versions
  - [x] Get Type
    - [x] GET http://`$PiHoleHost`/admin/api.php?type
  - [x] Get Summary
    - [x] GET http://`$PiHoleHost`/admin/api.php?summary
    - [x] GET http://`$PiHoleHost`/admin/api.php?summaryRaw
  - [x] Get Status
    - [x] GET http://`$PiHoleHost`/admin/api.php?status&auth=`$apiKey` 
    - [x] GET http://`$PiHoleHost`/admin/api_db.php?status&auth=`$apiKey` 
  - [x] Get DB File Size
    - [x] GET http://`$PiHoleHost`/admin/api_db.php?getDBfilesize&auth=`$apiKey` 
- [ ] Data / Stats
  - [x] GET http://`$PiHoleHost`/admin/api.php?overTimeData10mins
  - [ ] GET http://`$PiHoleHost`/admin/api.php?topItems=$ItemCount&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?topItems&auth=`$apiKey` 
  - [ ] GET http://`$PiHoleHost`/admin/api.php?topClients&auth=`$apiKey` 
  - [ ] GET http://`$PiHoleHost`/admin/api.php?topClients=`$returnCount`&auth=`$apiKey` 
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getQuerySources&auth=`$apiKey` 
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getQuerySources=`$returnCount`&auth=`$apiKey` 
  - [ ] GET http://`$PiHoleHost`/admin/api.php?topClientsBlocked&auth=`$apiKey` 
  - [ ] GET http://`$PiHoleHost`/admin/api.php?topClientsBlocked=`$returnCount`&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getForwardDestinations&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getForwardDestinations=unsorted&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getQueryTypes&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getCacheInfo&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getAllQueries&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getAllQueries=`$returnCount`&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getAllQueries&from=`$start`&until=`$end`&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getAllQueries&domain=`$domain`auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getAllQueries&client=`$client`&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getAllQueries&type=`$queryType`&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getAllQueries&client=`$client`&type=`$queryType`&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getAllQueries&forwarddest=`$forwardDestination`&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?recentBlocked&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getForwardDestinationNames&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?overTimeDataQueryTypes&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?getClientNames&auth=`$apiKey`
  - [ ] GET http://`$PiHoleHost`/admin/api.php?overTimeDataClients&auth=`$apiKey`
- [x] Enable / Disable filtering
  - [x] GET http://`$PiHoleHost`/admin/api.php?enable&auth=`$apiKey`
  - [x] GET http://`$PiHoleHost`/admin/api.php?disable&auth=`$apiKey`
  - [x] GET http://`$PiHoleHost`/admin/api.php?disable=$Seconds&auth=`$apiKey`
- [x] Managing Lists
  - [x] GET http://`$PiHoleHost`/admin/api.php?list=`$list`&auth=`$apiKey`
  - [x] GET http://`$PiHoleHost`/admin/api.php?list=`$list`&add=`$entry`&auth=`$apiKey`
  - [x] GET http://`$PiHoleHost`/admin/api.php?list=`$list`&sub=`$entry`&auth=`$apiKey`
- [ ] Managing DHCP Leases
  - [ ] GET http://`$PiHoleHost`/admin/api.php?delete_lease=`$dhcpLease`&auth=`$apiKey`
