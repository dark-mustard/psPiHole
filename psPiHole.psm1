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
        enum PiHoleListTypes{
            white
            black
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
                    [String]$ComputerName
                )
                try{
                    $Return = [PSCustomObject]@{
                        HostAPIUrlRoot = "http://$ComputerName/admin/api.php"
                        ClientID       = $ComputerName
                        #ClientSecret = $(ConvertFrom-SecureString -SecureString $(_Get-SecureString -Message "Please provide the API Client Secret for Client ID [$ComputerName]"))
                        ClientSecret   = $(_Get-SecureString -Message "Please provide the API Client Secret for Client ID [$ComputerName]")
                    }
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
                  PS> phInvoke-PiHoleAPI -ClientID 192.168.1.10 -HostAPIUrlRoot 'http://192.168.1.10/admin/api/' -APIEndPoint 'version'
                  Submits an anonymous request to the 'version' endpoint.

                  .EXAMPLE
                  PS> $APIKey = Read-Host -AsSecureString -Prompt "Please provide your API key."
                  PS> phInvoke-PiHoleAPI -ClientID 192.168.1.10 -HostAPIUrlRoot 'http://192.168.1.10/admin/api/' -APIEndPoint '' -ClientSecret $APIKey
                  Submits an anonymous request to the 'version' endpoint.
                #>
                [CmdletBinding()]
                #[Alias('')]
                param(
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Anonymous")]
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Authenticated")]
                    [String]
                    [ValidateNotNullOrEmpty()]
                        $ClientID,
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Anonymous")]
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Authenticated")]
                    [String]
                    [ValidateNotNullOrEmpty()]
                        $HostAPIUrlRoot,
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Anonymous")]
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Authenticated")]
                    [String]
                    [ValidateNotNullOrEmpty()]
                        $APIEndpoint,
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Authenticated")]
                    [SecureString]
                    [ValidateNotNull()]
                        $ClientSecret
                )
        
                $ReturnValue=$null

                $rootURL = $HostAPIUrlRoot

                switch ($PsCmdlet.ParameterSetName) {
                    "Anonymous" {
                        $uri = "{0}?{1}" -f $rootURL, $apiEndpoint
                    }
                    "Authenticated" {
                        $uri = "{0}?{1}&auth={2}" -f $rootURL, $apiEndpoint, $(_Decrypt-String -EncryptedString $ClientSecret)
                    }
                    default { 
                        $uri     = $null
                        throw ("Unhandled parameter set encountered. {0} 'Function':'{2}', 'ParameterSetName':'{3}' {1}" -f "[", "}", $MyInvocation.MyCommand.Name, $PsCmdlet.ParameterSetName)
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
                function  phGet-PiHoleVersion{
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $ClientID,
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot
                    )
                    $APIEndpoint = 'version'
                    $Params = @{
                        ClientID               = $ClientID
                        HostAPIUrlRoot         = $HostAPIUrlRoot
                        APIEndpoint            = $APIEndpoint
                    }
                    phInvoke-PiHoleAPI @Params
                }
                function  phGet-PiHoleType{
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $ClientID,
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot
                    )
                    $APIEndpoint = 'type'
                    $Params = @{
                        ClientID               = $ClientID
                        HostAPIUrlRoot         = $HostAPIUrlRoot
                        APIEndpoint            = $APIEndpoint
                    }
                    phInvoke-PiHoleAPI @Params
                }
                function  phGet-PiHoleSummary{
                    [CmdletBinding()]
                    #[Alias('')]
                    param(
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $ClientID,
                        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                        [String]
                            $HostAPIUrlRoot,
                        [Parameter()]
                        [Switch]
                            $Raw
                    )
                    $APIEndpoint=if(-Not $Raw){ "summary" } else { "summaryRaw" }
                    $Params = @{
                        ClientID               = $ClientID
                        HostAPIUrlRoot         = $HostAPIUrlRoot
                        APIEndpoint            = $APIEndpoint
                    }
                    phInvoke-PiHoleAPI @Params
                }
            #endregion
        #endregion
    #endregion
#endregion

_Initialize-Module