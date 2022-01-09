# Known API Endpoints
## Anonymous Endpoints
- [x] GET http://`$PiHoleHost`/admin/api.php?versions
```powershell
function  phGet-Version{
	param()
	<#...#>
}
```
- [x] GET http://`$PiHoleHost`/admin/api.php?type
```powershell
function  phGet-Type{
	param()
	<#...#>
}
```
- [x] Get Summary
  - [x] GET http://`$PiHoleHost`/admin/api.php?summary
  - [x] GET http://`$PiHoleHost`/admin/api.php?summaryRaw
```powershell
function  phGet-Summary{
	[CmdletBinding()]
	#[Alias('')]
	param(
		[Parameter()]
		[Switch]
			$raw
	)
	<#...#>
}
```
- [ ] GET http://`$PiHoleHost`/admin/api.php?list=`$list`
```powershell
function phGet-List{
	param(
		[String]
		[ValidateSet('white', 'black')]
			$list
	)
	<#...#>
}
```
- [ ] GET http://`$PiHoleHost`/admin/api.php?overTimeData10mins

## Authenticated Endpoints
- [ ] GET http://`$PiHoleHost`/admin/api.php?topItems=$ItemCount&auth=`$apiKey`
- [ ] GET http://`$PiHoleHost`/admin/api.php?enable&auth=`$apiKey`
- [ ] GET http://`$PiHoleHost`/admin/api.php?disable=$Seconds&auth=`$apiKey`
- [ ] GET http://`$PiHoleHost`/admin/api.php?getDBfilesize&auth=`$apiKey`
- [ ] GET http://`$PiHoleHost`/admin/api.php?list=`$list`&add=`$add`&auth=`$apiKey`
```powershell
function phNew-ListEntry{
	param(
		[String]
		[ValidateSet('white', 'black')]
			$list,
		[String]
		[ValidateNotNullOrEmpty()]
			$add,
		[Object]
		[ValidateNotNull()]
			$auth

	)
	<#...#>
}
```
