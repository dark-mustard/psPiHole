#region Locel Module Management
    #region Module Classes / Types
        <#
        class ModuleException : Exception {

            hidden [object] $_callStack
            hidden [object] $_callingFunction
            hidden [object] $_additionalDetails
        
            ModuleException($Message, $callStack, $callingFunction, $additionalDetails) : base($Message) {
                $this.InitializeObject($callStack, $callingFunction, $additionalDetails)
            }

            #region Initialization
                #----
                hidden CreateROPropertyAccessors() {
                    $Members = $this | phGet-Member -Force -MemberType Property -Name '_*'
                    ForEach ($Member in $Members) {
                        $PublicPropertyName = $Member.Name -replace '_', ''
                        #--
                        $GetAccessorDefinition = "return `$this.{0}" -f $Member.Name
                        #$GetAccessorDefinition = "return `$this.Get{0}()" -f $Member.Name
                        $GetAccessor = [ScriptBlock]::Create($GetAccessorDefinition)
                        #--
                        $SetAccessorDefinition = "Write-Warning 'This property cannot be modified.'"
                        $SetAccessor = [ScriptBlock]::Create($SetAccessorDefinition)
                        #--
                        $AddMemberParams = @{
                            Name = $PublicPropertyName
                            MemberType = 'ScriptProperty'
                            Value = $GetAccessor
                            SecondValue = $SetAccessor
                        }
                        $this | Add-Member @AddMemberParams
                    }
                }
                hidden InitializeObject ($callStack, $callingFunction, $additionalDetails) {
                    # Set initial object property values
                    $this._callStack       = $callStack
                    $this._callingFunction = $callingFunction
                    $this._additionalData  = $additionalDetails

                    # Generate GET accessors for any "Read Only" properties (hidden props beginning with '$_*')
                    $this.CreateROPropertyAccessors()
                }
                #----
            #endregion
            #region <Cleanup>
                #----
                [Void] Dispose() {
                    $this | phGet-Member -Force -MemberType Property  | %{
                        $_.Value = $null
                    }
                    #$Members = $this | phGet-Member -Force -MemberType Property 
                    #$Members | %{
                    #    $Member=$_
                    #    $this."$($Member.Name)"
                    #}
                }
                #----
            #endregion
        }
    #>
    #endregion
    #region Module Functions
    function _Initialize-Module{
        Write-Host "Hello World"

    }
    function _Dispose-Module{
        Write-Host "See you in HELL."
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
        #$CallStack    = @(Get-PSCallStack) 
        #$LastFunction = $CallStack[1] # Gets calling function from CallStack

        <#
        switch ($PsCmdlet.ParameterSetName) {
            "From_String" {
                #$ErrorObject = [ModuleException]::Create($Message, $CallStack, $LastFunction, $AdditionalData)
                try { $Message } catch { $ErrorObject = $_ }
            }
            "From_ErrorRecord" {
                $ErrorObject = $Exception
            }
            default { 
                throw ("Unhandled parameter set encountered. {0} 'Function':'{2}', 'ParameterSetName':'{3}' {1}" -f "[", "}", $MyInvocation.MyCommand.Name, $PsCmdlet.ParameterSetName)
            }
        }
        #>
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
        <#
        function  phGet-ThisScript{
            # Retrieves currently executing script
            $ScriptPath = $null
            $CallStack  = @(Get-PSCallStack)
            #$ThisScript = $null
            #$ThisScript = @($CallStack | Where { $_.Command -like "*.ps*" -and $_.ScriptName -like "$PSScriptRoot\*"  } | Select * -First 1)[0]
            $ThisScript = @($CallStack | Where { $_.Command -like "*.ps*" } | Select * -First 1)[0]
            
            #@(for($a = 1; $a -le $CallStack.Count; $a++){
            #    $CallStackItem = $CallStack[$a]
            #    if($CallStackItem.Command -like "*.ps*"){
            #        $ScriptPath = $CallStackItem.ScriptName
            #        $ThisScript = $CallStackItem
            #        # End loop
            #        $a = $CallStack.Count
            #    }
            #})
            
            #return $ScriptPath
            return $ThisScript
        }

        function  phGet-ScriptFunctions{
            [CmdletBinding()]
            [Alias('')]
            param(
                [Parameter()]
                [String]
                [ValidateNotNullOrEmpty()]
                    $Path
            )
            if([String]::IsNullOrWhiteSpace($Path)){
                $Path = phGet-ThisScript
            }
            try{
                $Functions = @(Invoke-Command -ComputerName "." -ArgumentList $Path -ScriptBlock {
                    param(
                        [Parameter(Mandatory)]
                        [String]
                        [ValidateNotNullOrEmpty()]
                            $Path
                    )
                    $currentFunctions = phGet-ChildItem function:
                    # dot source your script to load it to the current runspace
                    . $Path
                    $scriptFunctions = phGet-ChildItem function: | Where-Object { $currentFunctions -notcontains $_ }

                    $scriptFunctions | ForEach-Object {
                        & $_.ScriptBlock
                    }
                })
            } catch {
                $Functions = $null
                throw $_
            }
            return $Functions    
        }
        #>
#endregion
#endregion
#region PiHole-PoSh
#region Types and Enums
    enum PiHoleListTypes{
        white
        black
    }
#endregion
#region Custom Functions
    #region Configuration
        function  phNew-PiHoleHostConfig{
            param(
                [String]$ComputerName
            )
            try{
                $Return = [PSCustomObject]@{
                    HostAPIUrlRoot = "http://$ComputerName/admin/api.php"
                    ClientID       = $ComputerName
                    ClientSecret = $(ConvertFrom-SecureString -SecureString $(_Get-SecureString -Message "Please provide the API Client Secret for Client ID [$ComputerName]"))
                }
            } catch {
                $Return = $null
                throw $_
            }
            return $Return
        }
        function  phNew-PiHoleConfig{
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


            $PiHoleHostList | %{
                $PiHoleHostName = $_
                $PiHoleHostConfig = $(phNew-PiHoleHostConfig -ComputerName $PiHoleHostName)
                $Return.HostConfigs+=,$PiHoleHostConfig
            }

            return $Return
        }
    #endregion
    #region API
        function  phInvoke-PiHoleAPI{
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
                [String]
                [ValidateNotNullOrEmpty()]
                    $ClientSecret
            )
    
            $ReturnValue=$null

            $rootURL = $HostAPIUrlRoot

            switch ($PsCmdlet.ParameterSetName) {
                "Anonymous" {
                    $uri = "{0}?{1}" -f $rootURL, $apiEndpoint
                }
                "Authenticated" {
                    $uri = "{0}?{1}&auth={2}" -f $rootURL, $apiEndpoint, $ClientSecret
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