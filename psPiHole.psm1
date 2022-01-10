#region Local Module Management
    #region Module Functions
        function _Initialize-Module{
            #throw "Not implemented."
        }
        function _Dispose-Module{
           #throw "Not implemented."
        }
        function _Handle-Exception{
            [CmdletBinding()]
            #[Alias('')]
            param(
                [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                [Object]
                    $Message,
                [Parameter(ValueFromPipelineByPropertyName)]
                [object]
                    $AdditionalData,
                [Parameter(ValueFromPipelineByPropertyName)]
                [Switch]
                    $Throw
            )
            $ErrorObject  = $null

            switch ($Message.GetType().Name ) {
                "String" {
                    #$ErrorObject = [ModuleException]::Create($Message, $CallStack, $LastFunction, $AdditionalData)
                    try { $Message } catch { $ErrorObject = $_ }
                }
                "ErrorRecord" {
                    $ErrorObject = $Message
                }
                default { 
                    throw ("Unhandled parameter set encountered. {0} 'Function':'{2}', 'ParameterSetName':'{3}' {1}" -f "[", "}", $MyInvocation.MyCommand.Name, $PsCmdlet.ParameterSetName)
                }
            }

            if($null -ne $ErrorObject){
                # Add to session info object
                $script:ModuleInfo.Errors+=,$ErrorObject

                # Throw? or just Display?
                if($Throw){
                    throw $ErrorObject
                } else {
                    $MessageLineArray = @(
                        ("The following exception was encountered:")
                        $Indent=" ! "
                        ("{0}{1} : {2}" -f $Indent, $ErrorObject.InvocationInfo.InvocationName, $ErrorObject.Exception.Message)
                        @($ErrorObject.InvocationInfo.PositionMessage.Split([Environment]::NewLine).Where({ -Not [String]::IsNullOrWhiteSpace($_) })) | ForEach-Object{
                            ("{0}{1}" -f $Indent, $_)
                        }
                        ("{0}    + CategoryInfo          : {1}" -f $Indent, $ErrorObject.CategoryInfo.ToString())
                        ("{0}    + FullyQualifiedErrorId : {1}" -f $Indent, $ErrorObject.FullyQualifiedErrorId.ToString())
                    )
                    $MessageLineArray | ForEach-Object {
                        Write-Error ($MessageLineArray -join [Environment]::NewLine)
                    }
                }
            }
        }
    #endregion
    #region Module Events
        $ExecutionContext.SessionState.Module.OnRemove = {
            _Dispose-Module
        }
    #endregion
    #region Helper Functions
        function _Get-RequiredParam{
            param(
                [String]$ParamName,
                [String]$ParamValue=$null
            )
            $Message="Please provide a string value for [$ParamName]:"
            if(-Not $ParamValue) {
                $ParamValue = Read-Host -Prompt $Message
            }
            return $ParamValue
        }
        function _Get-SecureString{
            param(
                [String]$TextString=$null,
                [String]$Message="Please provide a string value to encrypt"
            )
            if($TextString) {
                $secureString = ConvertTo-SecureString $TextString -AsPlainText -Force
            } else {
                $secureString = Read-Host -AsSecureString -Prompt $Message
            }
            $secureString
        }
        function _Encrypt-String{
            param(
                [String]$TextString=$null
            )
            $secureString = _Get-SecureString -TextString $TextString
            return (ConvertFrom-SecureString -SecureString $secureString)
        }
        function _Decrypt-String{
            param(
                [object]$EncryptedString=$null
            )
            if($null -ne $EncryptedString) {
                switch($EncryptedString.GetType().Name){
                    ("String"){
                        $secureString = ConvertTo-SecureString $EncryptedString
                    }
                    ("SecureString"){
                        $secureString = $EncryptedString
                        # DO NOTHING
                    }
                }
            } else {
                $secureString = Read-Host -AsSecureString -Prompt "Please provide a string value to decrypt"
            }
            return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))
        }
    #endregion
#endregion
#region psPiHole
    #region Types and Enums
        enum PiHoleListType{
            white
            regex_white
            black
            regex_black
        }
    #endregion
    #region Custom Functions
        #region Configuration
            function phNew-PiHoleHostConfig{
                <#
                  .SYNOPSIS
                  Creates a custom object containing Pi-Hole host information.
            
                  .DESCRIPTION
                  Creates a custom object containing Pi-Hole host information.
            
                  .EXAMPLE
                  PS> phNew-PiHoleHostConfig -Computername '192.168.1.10'
                #>
                param(
                    [Parameter(Mandatory)]
                    [String]
                        $ComputerName,
                    [Parameter()]
                    [Int32]
                        $Port = 80,
                    [Parameter()]
                    [switch]
                        $Https
                )
                try{
                    $Return = [PSCustomObject]@{
                        HTTPType       = $(if($Https){ "https" } else { "http" })
                        Port           = $Port
                        #HostAPIUrlRoot = "http://$ComputerName/admin/api.php"
                        ClientID       = $ComputerName
                        #ClientSecret = $(ConvertFrom-SecureString -SecureString $(_Get-SecureString -Message "Please provide the API Client Secret for Client ID [$ComputerName]"))
                        ClientSecret   = $(_Get-SecureString -Message "Please provide the API Client Secret for Client ID [$ComputerName]")
                    }
                    $HostAPIUrlRoot = "{0}://{1}:{2}/admin" -f $Return.HTTPType, $Return.ClientId, $Return.Port
                    $Return | Add-Member -MemberType NoteProperty -Name "HostAPIUrlRoot" -Value $HostAPIUrlRoot
                } catch {
                    $Return = $null
                    throw $_
                }
                return $Return
            }
            function phNew-PiHoleHostCollection{
                <#
                  .SYNOPSIS
                  Creates an array of custom objects containing Pi-Hole host information.
            
                  .DESCRIPTION
                  Creates an array of custom objects containing Pi-Hole host information.
            
                  .EXAMPLE
                  PS> phNew-PiHoleHostCollection -PiHoleHostList @('192.168.1.10', '192.168.1.11')
                #>
                [Alias("phNew-PiHoleConfig")]
                [CmdletBinding()]
                param(
                    [Parameter(Mandatory)]
                    [String[]]
                    [ValidateNotNull()]
                        $PiHoleHostList
                )
                $Return = [PSCustomObject]@{
                    HostNames   = $PiHoleHostList
                    HostConfigs = @()
                }

                $PiHoleHostList | ForEach-Object {
                    $PiHoleHostName = $_
                    $PiHoleHostConfig = $(phNew-PiHoleHostConfig -ComputerName $PiHoleHostName)
                    $Return.HostConfigs+=,$PiHoleHostConfig
                }

                return $Return
            }
        #endregion
        #region API
            function phInvoke-PiHoleAPI{
                <#
                  .SYNOPSIS
                  Formats and submits a specified request to the specified host.
            
                  .DESCRIPTION
                  Formats and submits a specified request to the specified host.
            
                  .EXAMPLE
                  PS> phInvoke-PiHoleAPI -HostAPIUrlRoot 'http://192.168.1.10/admin' -APIEndPoint 'version'
                  Submits an anonymous request to the 'api.php' endpoint calling the 'version' method.

                  .EXAMPLE
                  PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                  PS> phInvoke-PiHoleAPI -ClientID 192.168.1.10 -HostAPIUrlRoot 'http://192.168.1.10/admin' -APIEndPoint 'api_db.php' -APIMethod 'getDBfilesize' -ClientSecret $APIKey
                  Submits an authenticated request to the 'api_db.php' endpoint calling the 'getDBfilesize' method.
                #>
                [CmdletBinding()]
                #[Alias('')]
                param(
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Anonymous")]
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Authenticated")]
                    [String]
                    [ValidateNotNullOrEmpty()]
                        $HostAPIUrlRoot,
                    [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = "Anonymous")]
                    [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = "Authenticated")]
                    [String]
                    [ValidateNotNullOrEmpty()]
                    [ValidateSet('api.php', 'api_db.php')]
                        $APIEndpoint = 'api.php',
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Anonymous")]
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Authenticated")]
                    [String]
                    [ValidateNotNullOrEmpty()]
                        $APIMethod,
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Authenticated")]
                    [SecureString]
                    [ValidateNotNull()]
                        $ClientSecret
                )
        
                $ReturnValue=$null

                $details = [PSCustomObject]@{
                    Function         = $(@(Get-PSCallStack)[1].FunctionName)
                    ParameterSetName = $($PsCmdlet.ParameterSetName)
                }

                switch ($PsCmdlet.ParameterSetName) {
                    "Anonymous" {
                        $uri = "{0}/{1}?{2}" -f $HostAPIUrlRoot, $APIEndpoint, $APIMethod
                    }
                    "Authenticated" {
                        $auth = _Decrypt-String -EncryptedString $ClientSecret
                        $uri = "{0}/{1}?{2}&auth={3}" -f $HostAPIUrlRoot, $APIEndpoint, $APIMethod, $auth
                    }
                    default { 
                        $uri     = $null
                        $details = [PSCustomObject]@{
                            Function         = $MyInvocation.MyCommand.Name
                            #Function         = $(@(Get-PSCallStack)[0].FunctionName)
                            #Function         = $(@(Get-PSCallStack)[1].FunctionName)
                            ParameterSetName = $($PsCmdlet.ParameterSetName)
                        }
                        throw ("Unhandled parameter set encountered. {0}" -f $($details | ConvertTo-Json -Compress))
                    }
                }

                if(-Not [String]::IsNullOrWhiteSpace($uri)){
                    try{
                            
                        $Response=Invoke-WebRequest -Uri $uri
                        if($Response.StatusCode -eq 200) {
                            $ReturnValue=($Response.Content | ConvertFrom-Json)
                        } else {
                            $Message="Web request failed with code {0}: {1}" -f $Response.StatusCode, $Response.StatusDescription
                            _Handle-Exception -Message  $Message
                            #throw $Message
                        }
                    } catch {
                        #Write-Error $_.Exception.Message
                        _Handle-Exception -Message $_ -Throw
                        #throw $_
                    }
                }

                return $ReturnValue
            }
            #region Server Status
                function phGet-PiHoleStatus{
                    <#
                      .SYNOPSIS
                      Gets the current status of the specified PiHole host.
                
                      .DESCRIPTION
                      Gets the current status of the specified PiHole host.
                
                      .EXAMPLE
                      PS> phGet-PiHoleStatus -HostAPIUrlRoot 'http://192.168.1.10/admin'
                      Pulls the current status of the host with the ip 192.168.1.10.

                      .EXAMPLE
                      PS> phGet-PiHoleStatus -HostAPIUrlRoot 'http://192.168.1.10/admin' -Database
                      Pulls the current database status of the host with the ip 192.168.1.10.
                    #>
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot,
                        [Parameter()]
                        [Switch]
                            $Database
                    )
                    $APIEndpoint = if($Database) { "api_db.php" } else { "api.php" }
                    $APIMethod   = 'status'
                    $Params = @{
                        HostAPIUrlRoot = $HostAPIUrlRoot
                        APIEndpoint    = $APIEndpoint
                        APIMethod      = $APIMethod
                    }
                    return (phInvoke-PiHoleAPI @Params)
                }
                function phGet-PiHoleVersion{
                    <#
                      .SYNOPSIS
                      Gets the current version of the specified PiHole host.
                
                      .DESCRIPTION
                      Gets the current version of the specified PiHole host.
                
                      .EXAMPLE
                      PS> phGet-PiHoleVersion -HostAPIUrlRoot 'http://192.168.1.10/admin'
                      Pulls the current version of the host with the ip 192.168.1.10.

                      .EXAMPLE
                      PS> phGet-PiHoleVersion -HostAPIUrlRoot 'http://192.168.1.10/admin' -Details
                      Pulls the full current version details of the host with the ip 192.168.1.10.
                    #>
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot,
                        [Parameter()]
                        [Switch]
                            $Details
                    )
                    $APIEndpoint = "api.php"
                    $APIMethod   = if($Details){ 'versions' } else { 'version' }
                    $Params = @{
                        HostAPIUrlRoot = $HostAPIUrlRoot
                        APIEndpoint    = $APIEndpoint
                        APIMethod      = $APIMethod
                    }
                    return (phInvoke-PiHoleAPI @Params)
                }
                function phGet-PiHoleType{
                    <#
                      .SYNOPSIS
                      Gets the current type of the specified PiHole host.
                
                      .DESCRIPTION
                      Gets the current type of the specified PiHole host.
                
                      .EXAMPLE
                      PS> phGet-PiHoleType -HostAPIUrlRoot 'http://192.168.1.10/admin'
                      Pulls the current type of the host with the ip 192.168.1.10.
                    #>
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot
                    )
                    $APIEndpoint = "api.php"
                    $APIMethod   = 'type'
                    $Params = @{
                        HostAPIUrlRoot = $HostAPIUrlRoot
                        APIEndpoint    = $APIEndpoint
                        APIMethod      = $APIMethod
                    }
                    return (phInvoke-PiHoleAPI @Params)
                }
                function phGet-PiHoleSummary{
                    <#
                      .SYNOPSIS
                      Gets the current host summary of the specified PiHole host.
                
                      .DESCRIPTION
                      Gets the current host summary of the specified PiHole host.
                
                      .EXAMPLE
                      PS> phGet-PiHoleType -HostAPIUrlRoot 'http://192.168.1.10/admin'
                      Pulls the current host summary of the host with the ip 192.168.1.10.

                      .EXAMPLE
                      PS> phGet-PiHoleType -HostAPIUrlRoot 'http://192.168.1.10/admin' -Raw
                      Pulls the current host summary (unformated) of the host with the ip 192.168.1.10.
                    #>
                    [CmdletBinding()]
                    #[Alias('')]
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot,
                        [Parameter()]
                        [Switch]
                            $Raw
                    )
                    $APIEndpoint = "api.php"
                    $APIMethod   = if($Raw){ "summaryRaw" } else { "summary" }
                    $Params = @{
                        HostAPIUrlRoot = $HostAPIUrlRoot
                        APIEndpoint    = $APIEndpoint
                        APIMethod      = $APIMethod
                    }
                    return (phInvoke-PiHoleAPI @Params)
                }
            #endregion
            #region Data & Stats
                function phGet-PiHoleDataLast10Min{
                    <#
                      .SYNOPSIS
                      Gets the current host summary of the specified PiHole host.
                
                      .DESCRIPTION
                      Gets the current host summary of the specified PiHole host.
                
                      .EXAMPLE
                      PS> phGet-PiHoleDataLast10Mins -HostAPIUrlRoot 'http://192.168.1.10/admin'
                      Pulls the last 10 minutes of data from the host with the ip 192.168.1.10.
                    #>
                    [CmdletBinding()]
                    #[Alias('')]
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot
                    )
                    $APIEndpoint = "api.php"
                    $APIMethod   = "overTimeData10mins"
                    $Params = @{
                        HostAPIUrlRoot = $HostAPIUrlRoot
                        APIEndpoint    = $APIEndpoint
                        APIMethod      = $APIMethod
                    }
                    return (phInvoke-PiHoleAPI @Params)
                }
            #endregion
            #region Enable / Disable
                function phEnable-PiHole{
                    <#
                    .SYNOPSIS
                    Enables filtering on the specified PiHole host.
                
                    .DESCRIPTION
                    Enables filtering on the specified PiHole host.
                
                    .EXAMPLE
                    PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                    PS> phEnable-PiHole -HostAPIUrlRoot 'http://192.168.1.10/admin' -ClientSecret $APIKey
                    Enables filtering on the host with the ip 192.168.1.10.

                    #>
                    [CmdletBinding()]
                    #[Alias('')]
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot,
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [SecureString]
                            $ClientSecret
                    )
                    $APIEndpoint = "api.php"
                    $APIMethod   = "enable"
                    $Params = @{
                        HostAPIUrlRoot = $HostAPIUrlRoot
                        APIEndpoint    = $APIEndpoint
                        APIMethod      = $APIMethod
                        ClientSecret   = $ClientSecret
                    }
                    return (phInvoke-PiHoleAPI @Params)
                }
            #endregion
            #region Manage Lists
                function phGet-PiHoleList{
                    <#
                      .SYNOPSIS
                      Gets the list entries of the specified list on the specified PiHole host.
                
                      .DESCRIPTION
                      Gets the list entries of the specified list on the specified PiHole host.
                
                      .EXAMPLE
                      PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                      PS> phGet-PiHoleList -HostAPIUrlRoot 'http://192.168.1.10/admin' -ClientSecret $APIKey -List black
                      Pulls blacklist entries from the host with the ip 192.168.1.10.

                      .EXAMPLE
                      PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                      PS> phGet-PiHoleList -HostAPIUrlRoot 'http://192.168.1.10/admin' -ClientSecret $APIKey -List regex_white 
                      Pulls regex whitelist entries from the host with the ip 192.168.1.10.
                    #>
                    [CmdletBinding()]
                    #[Alias('')]
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot,
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [SecureString]
                            $ClientSecret,
                        [Parameter(Mandatory)]
                        [PiHoleListType]
                            $List
                    )
                    $APIEndpoint = "api.php"
                    $APIMethod   = "list={0}" -f $List.ToString()
                    $Params = @{
                        HostAPIUrlRoot = $HostAPIUrlRoot
                        APIEndpoint    = $APIEndpoint
                        APIMethod      = $APIMethod
                        ClientSecret   = $ClientSecret
                    }
                    return @((phInvoke-PiHoleAPI @Params) | Select-Object @{ Name="List"; Expression={ $List.ToString() } }, `
                                                                          @{ Name="Entries"; Expression={ $_.data } })
                }
                function phNew-PiHoleListEntry{
                    <#
                      .SYNOPSIS
                      Adds an entry to the specified list on the specified host.
                
                      .DESCRIPTION
                      Adds an entry to the specified list on the specified host.
                
                      .EXAMPLE
                      PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                      PS> phNew-PiHoleListEntry -HostAPIUrlRoot 'http://192.168.1.10/admin' -ClientSecret $APIKey -List black -Entry 'test.local'
                      Adds 'test.local' to the blacklist on the host with the ip 192.168.1.10.

                      .EXAMPLE
                      PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                      PS> phNew-PiHoleListEntry -HostAPIUrlRoot 'http://192.168.1.10/admin' -ClientSecret $APIKey -List regex_white -Entry '(\.|^)test\.local$'
                      Adds '(\.|^)test\.local$' to the regex whitelist on the host with the ip 192.168.1.10.
                    #>
                    [CmdletBinding()]
                    #[Alias('')]
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot,
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [SecureString]
                            $ClientSecret,
                        [Parameter(Mandatory)]
                        [PiHoleListType]
                            $List,
                        [Parameter(Mandatory)]
                        [string]
                        [ValidateNotNullOrEmpty()]
                            $Entry
                    )
                    $APIEndpoint = "api.php"
                    $APIMethod   = "list={0}&add={1}" -f $List.ToString(), $Entry
                    $Params = @{
                        HostAPIUrlRoot = $HostAPIUrlRoot
                        APIEndpoint    = $APIEndpoint
                        APIMethod      = $APIMethod
                        ClientSecret   = $ClientSecret
                    }
                    return (phInvoke-PiHoleAPI @Params)
                }
                function phRemove-PiHoleListEntry{
                    <#
                      .SYNOPSIS
                      Removes an entry from the specified list on the specified host.
                
                      .DESCRIPTION
                      Removes an entry from the specified list on the specified host.
                
                      .EXAMPLE
                      PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                      PS> phRemove-PiHoleListEntry -HostAPIUrlRoot 'http://192.168.1.10/admin' -ClientSecret $APIKey -List black -Entry 'test.local'
                      Removes 'test.local' to the blacklist on the host with the ip 192.168.1.10.

                      .EXAMPLE
                      PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                      PS> phRemove-PiHoleListEntry -HostAPIUrlRoot 'http://192.168.1.10/admin' -ClientSecret $APIKey -List regex_white -Entry '(\.|^)test\.local$'
                      Removes '(\.|^)test\.local$' to the regex whitelist on the host with the ip 192.168.1.10.
                    #>
                    [CmdletBinding()]
                    #[Alias('')]
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot,
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [SecureString]
                            $ClientSecret,
                        [Parameter(Mandatory)]
                        [PiHoleListType]
                            $List,
                        [Parameter(Mandatory)]
                        [string]
                        [ValidateNotNullOrEmpty()]
                            $Entry
                    )
                    $APIEndpoint = "api.php"
                    $APIMethod   = "list={0}&sub={1}" -f $List.ToString(), $Entry
                    $Params = @{
                        HostAPIUrlRoot = $HostAPIUrlRoot
                        APIEndpoint    = $APIEndpoint
                        APIMethod      = $APIMethod
                        ClientSecret   = $ClientSecret
                    }
                    return (phInvoke-PiHoleAPI @Params)
                }
            #endregion
        #endregion
    #endregion
#endregion

_Initialize-Module