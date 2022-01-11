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
        enum PiHoleAPIEndPoints{
            api
            api_db
        }
        enum PiHoleListType{
            white
            regex_white
            black
            regex_black
        }
    #endregion
    #region Custom Functions
        #region Misc
            function _Get-PiHoleAPIEndpointName{
                [CmdletBinding()]
                [Alias("gphen")]
                param(
                    [Parameter(Mandatory, Position=0)]
                    [PiHoleAPIEndPoints]
                        $APIEndpoint
                )
                $Return = "{0}.php" -f $APIEndpoint.ToString()
                return $Return
            }
            function _Get-PiHoleHostFromUrl{
                [CmdletBinding()]
                param(
                    [Parameter(Mandatory, Position=0)]
                    [String]
                        $HostAPIUrlRoot
                )
                $PiHoleHost = $HostAPIUrlRoot.Substring($HostAPIUrlRoot.IndexOf("//") + 2)
                if($PiHoleHost -like "*:*"){
                    $PiHoleHost = $PiHoleHost.Substring(0, $PiHoleHost.IndexOf(":"))
                } else {
                    $PiHoleHost = $PiHoleHost.Substring(0, $PiHoleHost.IndexOf("/"))
                }
                return $PiHoleHost
            }
        #endregion
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
                        ClientID       = $ComputerName
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
            function _Invoke-PiHoleAPI{
                <#
                  .SYNOPSIS
                  Formats and submits a specified request to the specified host.
            
                  .DESCRIPTION
                  Formats and submits a specified request to the specified host.
            
                  .EXAMPLE
                  PS> _Invoke-PiHoleAPI -HostAPIUrlRoot 'http://192.168.1.10/admin' -APIEndPoint 'version'
                  Submits an anonymous request to the 'api.php' endpoint calling the 'version' method.

                  .EXAMPLE
                  PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                  PS> _Invoke-PiHoleAPI -ClientID 192.168.1.10 -HostAPIUrlRoot 'http://192.168.1.10/admin' -APIEndPoint 'api_db.php' -APIMethod 'getDBfilesize' -ClientSecret $APIKey
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
                    [PiHoleAPIEndPoints]
                        $APIEndpoint = ([PiHoleAPIEndPoints]::api),
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
                begin{
                    $Return = @()
                    $APIEndpointName = _Get-PiHoleAPIEndpointName $APIEndpoint
                }
                process{
                    switch ($PsCmdlet.ParameterSetName) {
                        "Anonymous" {
                            $uri = "{0}/{1}?{2}" -f $HostAPIUrlRoot, $APIEndpointName, $APIMethod
                        }
                        "Authenticated" {
                            $auth = _Decrypt-String -EncryptedString $ClientSecret
                            $uri = "{0}/{1}?{2}&auth={3}" -f $HostAPIUrlRoot, $APIEndpointName, $APIMethod, $auth
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
                            $Result=Invoke-WebRequest -Uri $uri
                            if($Result.StatusCode -eq 200) {
                                $Return += ($Result.Content | ConvertFrom-Json)
                            } else {
                                $Message="Web request failed with code {0}: {1}" -f $Result.StatusCode, $Result.StatusDescription
                                _Handle-Exception -Message  $Message -Throw
                            }
                        } catch {
                            _Handle-Exception -Message $_ -Throw
                        }
                    }
                }
                end{
                    return $Return
                }
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
                    begin{
                        $Return      = @()
                        $APIEndpoint = if($Database) { ([PiHoleAPIEndpoints]::api_db) } else { ([PiHoleAPIEndpoints]::api) }
                        $APIMethod   = 'status'
                    }
                    process{
                        $Params      = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                        }
                        $Return += (_Invoke-PiHoleAPI @Params)
                    }
                    end{
                        return $Return
                    }
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
                    begin{
                        $Return      = @()
                        $APIEndpoint = ([PiHoleAPIEndpoints]::api)
                        $APIMethod   = if($Details){ 'versions' } else { 'version' }
                    }
                    process{
                        $Params      = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                        }
                        $Return += (_Invoke-PiHoleAPI @Params)
                    }
                    end{
                        return $Return
                    }
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
                    begin {
                        $Return      = @()
                        $APIEndpoint = ([PiHoleAPIEndpoints]::api)
                        $APIMethod   = 'type'
                    }
                    process {
                        $Params = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                        }
                        $Return += (_Invoke-PiHoleAPI @Params)
                    }
                    end {
                        return $Return 
                    }
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
                    begin {
                        $Return      = @()
                        $APIEndpoint = ([PiHoleAPIEndpoints]::api)
                        $APIMethod   = if($Raw){ "summaryRaw" } else { "summary" }
                    }
                    process {
                        $Params = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                        }
                        $Return += (_Invoke-PiHoleAPI @Params)
                    }
                    end {
                        return $Return 
                    }
                }
                function phGet-DBFileSize{
                    <#
                      .SYNOPSIS
                      Gets the database file size (in bytes) of the specified PiHole host.
                
                      .DESCRIPTION
                      Gets the database file size (in bytes) of the specified PiHole host.
                
                      .EXAMPLE
                      PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                      PS> phGet-DBFileSize -HostAPIUrlRoot 'http://192.168.1.10/admin' -ClientSecret $APIKey
                      Pulls the current database file size for the host with the ip 192.168.1.10.
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
                    begin {
                        $Return      = @()
                        $APIEndpoint = ([PiHoleAPIEndpoints]::api_db)
                        $APIMethod   = "getDBfilesize"
                    }
                    process {
                        $Params = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                            ClientSecret   = $ClientSecret
                        }
                        $Return += (_Invoke-PiHoleAPI @Params)
                    }
                    end {
                        return $Return 
                    }
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
                    begin {
                        $Return      = @()
                        $APIEndpoint = ([PiHoleAPIEndpoints]::api)
                        $APIMethod   = "overTimeData10mins"
                    }
                    process {
                        $Params = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                        }
                        $Return += (_Invoke-PiHoleAPI @Params)
                    }
                    end {
                        return $Return 
                    }
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
                    begin {
                        $Return      = @()
                        $Action      = "Enable Filtering"
                        $APIEndpoint = ([PiHoleAPIEndpoints]::api)
                        $APIMethod   = "enable"
                    }
                    process {
                        $PiHoleHost = _Get-PiHoleHostFromUrl -HostAPIUrlRoot $HostAPIUrlRoot
                        $Params = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                            ClientSecret   = $ClientSecret
                        }
                        $Result = (_Invoke-PiHoleAPI @Params)
                        $Return += ([PSCustomObject]@{
                            PiHoleHost = $PiHoleHost
                            Action     = $Action
                            APIParams  = $Params
                            Result     = $Result
                            Status     = $Result.status
                        })
                    }
                    end {
                        return $Return 
                    }
                }
                function phDisable-PiHole{
                    <#
                    .SYNOPSIS
                    Disables filtering on the specified PiHole host.
                
                    .DESCRIPTION
                    Disables filtering on the specified PiHole host.
                
                    .EXAMPLE
                    PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                    PS> phDisable-PiHole -HostAPIUrlRoot 'http://192.168.1.10/admin' -ClientSecret $APIKey
                    Disables filtering on the host with the ip 192.168.1.10.
                
                    .EXAMPLE
                    PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                    PS> phDisable-PiHole -HostAPIUrlRoot 'http://192.168.1.10/admin' -ClientSecret $APIKey -Seconds 5
                    Disables filtering for 5 seconds on the host with the ip 192.168.1.10.

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
                        [Parameter()]
                        [Int32]
                            $Seconds = 0
                    )
                    begin {
                        $Return      = @()
                        $Action      = "Disable Filtering"
                        $APIEndpoint = ([PiHoleAPIEndpoints]::api)
                        $APIMethod   = "disable{0}" -f $(if($Seconds -gt 0){ "=$Seconds" })
                    }
                    process {
                        $PiHoleHost = _Get-PiHoleHostFromUrl -HostAPIUrlRoot $HostAPIUrlRoot
                        $Params = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                            ClientSecret   = $ClientSecret
                        }
                        $Result = (_Invoke-PiHoleAPI @Params)
                        $Return += ([PSCustomObject]@{
                            PiHoleHost = $PiHoleHost
                            Action     = $Action
                            APIParams  = $Params
                            Result     = $Result
                            Status     = $Result.status
                        })
                    }
                    end {
                        return $Return 
                    }
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
                    begin {
                        $Return      = @()
                        $APIEndpoint = ([PiHoleAPIEndpoints]::api)
                        $APIMethod   = "list={0}" -f $List.ToString()
                    }
                    process {
                        $PiHoleHost = _Get-PiHoleHostFromUrl -HostAPIUrlRoot $HostAPIUrlRoot
                        $Params = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                            ClientSecret   = $ClientSecret
                        }
                        $Result = (_Invoke-PiHoleAPI @Params)
                        $Return += ([PSCustomObject]@{
                            PiHoleHost = $PiHoleHost
                            Action     = $Action
                            APIParams  = $Params
                            List       = $($List.ToString())
                            Entry      = $Entry
                            Result     = $Result
                            Entries    = $Result.data
                        })
                    }
                    end {
                        return $Return 
                    }
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
                    begin {
                        $Return      = @()
                        $Action      = "New List Entry"
                        $APIEndpoint = ([PiHoleAPIEndpoints]::api)
                        $APIMethod   = "list={0}&add={1}" -f $List.ToString(), $Entry
                        $Params = @{}
                    }
                    process {
                        $PiHoleHost = _Get-PiHoleHostFromUrl -HostAPIUrlRoot $HostAPIUrlRoot
                        $Params = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                            ClientSecret   = $ClientSecret
                        }
                        $Result = (_Invoke-PiHoleAPI @Params)
                        $Return += ([PSCustomObject]@{
                            PiHoleHost = $PiHoleHost
                            Action     = $Action
                            APIParams  = $Params
                            List       = $($List.ToString())
                            Entry      = $Entry
                            Result     = $Result
                            Success    = $Result.success
                            Message    = $Result.message
                        })
                    }
                    end {
                        return $Return 
                    }
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
                    begin {
                        $Return      = @()
                        $Action      = "Remove List Entry"
                        $APIEndpoint = ([PiHoleAPIEndpoints]::api)
                        $APIMethod   = "list={0}&sub={1}" -f $List.ToString(), $Entry
                    }
                    process {
                        $PiHoleHost = _Get-PiHoleHostFromUrl -HostAPIUrlRoot $HostAPIUrlRoot
                        $Params = @{
                            HostAPIUrlRoot = $HostAPIUrlRoot
                            APIEndpoint    = $APIEndpoint
                            APIMethod      = $APIMethod
                            ClientSecret   = $ClientSecret
                        }
                        $Result = (_Invoke-PiHoleAPI @Params)
                        $Return += ([PSCustomObject]@{
                            PiHoleHost = $PiHoleHost
                            Action     = $Action
                            APIParams  = $Params
                            List       = $($List.ToString())
                            Entry      = $Entry
                            Result     = $Result
                            Success    = $Result.success
                            Message    = $Result.message
                        })
                    }
                    end {
                        return $Return 
                    }
                }
            #endregion
        #endregion
    #endregion
#endregion

_Initialize-Module