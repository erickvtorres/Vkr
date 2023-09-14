function Convert-OfficeSku {
<#
.SYNOPSIS
    Convert SKU to Friedly Name.

.DESCRIPTION
    Convert Office SKU IDs to friendly name, base on Microsoft License Service Plan Reference.

.LINK
    .Linkedin:      https://www.linkedin.com/in/erickvtorres/
    .GitHub:        https://github.com/erickvtorres
    .Reference:     https://learn.microsoft.com/en-us/azure/active-directory/enterprise-users/licensing-service-plan-reference

.NOTES
    .Creator:       Erick Torres do Vale
    .Contact:       ericktorres@hotmail.com.br
    .Date:          2023-09-13
    .LastUpdate:    2023-09-13
    .Version:       0.0.1

.PARAMETER All
    List all licenses available

.PARAMETER AccountSkuID
    Convert license from SkuID

.PARAMETER ProductName
Convert license from ProductName

.PARAMETER Guid
    Convert license from GUID

.EXAMPLE
    Convert-OfficeSku -All

    Convert-OfficeSku -AccountSkuID SPE_E3,SPE_E5
    ProductName      StringID GUID
    -----------      -------- ----
    Microsoft 365 E3 SPE_E3   05e9a617-0261-4cee-bb44-138d3ef5d965
    Microsoft 365 E5 SPE_E5   06ebc4ee-1bb5-47dd-8120-11324bc54e06

    Convert-OfficeSku -ProductName 'Microsoft 365 E3','Microsoft 365 E5'
    ProductName      StringID GUID
    -----------      -------- ----
    Microsoft 365 E3 SPE_E3   05e9a617-0261-4cee-bb44-138d3ef5d965
    Microsoft 365 E5 SPE_E5   06ebc4ee-1bb5-47dd-8120-11324bc54e06

    
    Convert-OfficeSku -Guid 05e9a617-0261-4cee-bb44-138d3ef5d965
    ProductName      StringID GUID
    -----------      -------- ----
    Microsoft 365 E3 SPE_E3   05e9a617-0261-4cee-bb44-138d3ef5d965

#>
    [CmdletBinding(DefaultParameterSetName = 'Sku')]
    param (
        [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true, ValueFromPipeline = $true, ParameterSetName = 'Sku')]
        [alias('SkuID')]
        [array]$AccountSkuID,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = 'ProductName')]
        [array]$ProductName,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = 'Guid')]
        [array]$Guid,

        [Parameter(Mandatory = $false, ParameterSetName = 'All')]
        [switch]$All
    )
    
    begin {
        try {
            $List = Import-Csv -Path $PSScriptRoot\LicNames.csv
        }
        catch {
            Write-Error -Message 'LicNames file is missing'
            Break
        }
    }
    
    process {
        switch ($PSBoundParameters.Keys) {
            AccountSkuID {
                $AccountSkuID | ForEach-Object {
                    $Name = $_
                    $List | Where-Object {$_.StringID -eq $Name}
                }
            }
            
            ProductName {
                $ProductName | ForEach-Object {
                    $Name = $_
                    $List | Where-Object {$_.ProductName -eq $Name}
                }
            }
                        
            Guid {
                $Guid | ForEach-Object {
                    $Name = $_
                    $List | Where-Object {$_.Guid -eq $Name}
                }
            }

            All          {
                Return $List
            }
            Default {}
        }
    }
    
    end {
        if (((Get-Date) - $(Get-Date -Date '2023-09-14')).Days -gt 360){
            Write-Warning -Message "Last update was 2023-09-14`nLink: https://learn.microsoft.com/en-us/azure/active-directory/enterprise-users/licensing-service-plan-reference" 
        }
    }
}
