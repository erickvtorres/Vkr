<#
.SYNOPSIS
    Get warranty for Dell devices.

.DESCRIPTION
    Connect to Dell API system using OpenAuthentication and get warranty information.
    To hard code Dell Key and Secret, edit $DellApiKey and $DellApiSecret in the
    Begin {} section, this option is overrided by passing this values in parameters.

    Some Serial Numbers are not Public and cannot be accessed by API or Website.
    Request Dell API Key by accessing the Dell Technet website

.LINK
    .Linkedin:      https://www.linkedin.com/in/erickvtorres/
    .GitHub:        https://github.com/erickvtorres
    .Dell API       https://tdm.dell.com/portal

.NOTES
    .Creator:       Erick Torres do Vale
    .Contact:       ericktorres@hotmail.com.br
    .Date:          2022-10-31
    .LastUpdate:    2023-03-22
    .Version:       1.0.1

.PARAMETER
    -ServiceTag:
        Input Dell Serial Number    
    -DellApiKey:
        Used to specify API Key instead hard coded.
    -DellApiSecret:
        Used to specify API Secret instead hard coded.
    
.EXAMPLE
    If you hard code Key and Secret
    Get-DellWarranty -ServiceTag A1B2C3D        # Passing in parameter
    A1B2C3D | Get-DellWarranty                  # Passing in pipeline
    $ServiceTags | Get-DellWarranty             # Passing multiple serial numbers from variable in pipeline

    If you do not hard code Key and Secret
    Get-DellWarranty -ServiceTag A1B2C3D -DellApiKey <your org api key> -DellApiSecret <your org api secret>
#>

function Get-DellWarranty {
    [CmdletBinding(DefaultParameterSetName = 'ServiceTag')]
    param (
        [Parameter(
            Position          = 0,
            Mandatory         = $true,
            ValueFromPipeline = $true,
            HelpMessage       = "Get-CimInstance -CimSession localhost -ClassName Win32_BIOS"
        )]
        [string]
        $ServiceTag,

        [Parameter(
            Mandatory   = $false,
            HelpMessage = "Enter your Dell API Key"
        )]
        [string]
        $DellApiKey,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Enter your Dell API Secret"
        )]
        [string]
        $DellApiSecret
    )
    
    begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Result     = @()
        $Global:Token = $null

        if (-Not ($DellApiKey)) {
            $DellApiKey = ""
        }

        if (-Not ($DellApiSecret)) {
            $DellApiSecret = ""
        }

        if (-Not ($Token)) {
            $OpenAuthentication = "$($DellApiKey):$($DellApiSecret)"
            $GetBytes = [System.Text.Encoding]::ASCII.GetBytes($OpenAuthentication)
            $EncodedOpenAuth = [Convert]::ToBase64String($GetBytes)
            
            $Params = @{
                Method  = "Post"
                Uri     = "https://apigtwb2c.us.dell.com/auth/oauth/v2/token"
                Body    = "grant_type=client_credentials"
                Headers = @{"Authorization" = "Basic $($EncodedOpenAuth)"}
            }
    
            $Authentication = Invoke-RestMethod @Params
            $Token = $Authentication.access_token
        }
    }
    
    process {
        $ParamsResponse = @{
            Uri         = "https://apigtwb2c.us.dell.com/PROD/sbil/eapi/v5/asset-entitlements"
            Headers     = @{
                Authorization   = "Bearer $($Token)"
                Accept          = "application/json"
            }
            Body        = @{
                servicetags = [string]$ServiceTag
                Method      = "Get"
            }
            Method      = "Get"
            ContentType = "application/json"
        }
        
        $DellApiReturn  = Invoke-RestMethod @ParamsResponse

        if ($DellApiReturn.invalid -eq 'True'){
            Write-Error -Message 'Invalid asset tag.'
            break
        }

        $Result = [PSCustomObject]@{
            ServiceTag      = $DellApiReturn.serviceTag
            Product         = (Get-Culture).TextInfo.ToTitleCase(($DellApiReturn.productLineDescription).toLower())
            Support         = ($DellApiReturn.entitlements | Select-Object -Last 1).serviceLevelDescription
            ShipDate        = $DellApiReturn.shipDate
            Expire          = ($DellApiReturn.entitlements | Select-Object -Last 1).endDate
            Status          = if ((Get-Date) -ge ($DellApiReturn.entitlements | Select-Object -Last 1).endDate){"Expired"} else {"Active"}
        }
        Return $Result
    }
    
    end {
        $Token = $null
    }
}
