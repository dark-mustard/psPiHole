[<img src="https://wp-cdn.pi-hole.net/wp-content/uploads/2016/12/Vortex-R.png" width="80">](https://pi-hole.net/)

# psPiHole
PowerShell API wrapper for managing one or more [Pi-Hole](https://pi-hole.net/) servers.

## Usage
### Getting Started

```powershell
Import-Module psPiHole

$phHost1 = phNew-PiHoleHostConfig -ComputerName "192.168.1.10"
$phHost1 | phGet-PiHoleSummary

Remove-Module psPiHole
```

### Managing *Multiple* Pi-Hole's
```powershell
$phHosts = phNew-PiHoleHostCollection -PiHoleHostList @("192.168.1.10", "192.168.1.11")

$phHosts.HostConfigs | phGet-PiHoleVersion
```

For a full list of known and implemented endpoints / methods, see [Endpoints.md](/Endpoints.md).
