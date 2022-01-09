### Anonymous Endpoints
- [ ] GET https://$PiHoleHost/admin/api.php?
- [ ] GET https://$PiHoleHost/admin/api.php?
- [ ] GET https://$PiHoleHost/admin/api.php?
- [ ] GET https://$PiHoleHost/admin/api.php?
- [ ] GET https://$PiHoleHost/admin/api.php?
```powershell
param(
	[String]
	[ValidateSet('white', 'black')]
		$List
)
```
- [ ] GET https://$PiHoleHost/admin/api.php?list=$List
- [ ] GET https://$PiHoleHost/admin/api.php?versions
- [ ] GET https://$PiHoleHost/admin/api.php?overTimeData10mins

### Authenticated Endpoints
- [ ] GET https://$PiHoleHost/admin/api.php?topItems=$ItemCount&auth=$APIKey
- [ ] GET https://$PiHoleHost/admin/api.php?enable&auth=$APIKey
- [ ] GET https://$PiHoleHost/admin/api.php?disable=$Seconds&auth=$APIKey
- [ ] GET https://$PiHoleHost/admin/api.php?getDBfilesize&auth=$APIKey
```powershell
function New-ListEntry{
	param(
		$List
	)
}
```
- [ ] GET https://$PiHoleHost/admin/api.php?