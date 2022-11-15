<#
.SYNOPSIS
    Rename user in a simple way

.DESCRIPTION
    Rename AD User object with SamAccountName property replacing Name.
    Makes easy administration and prevent problems with duplicated names.

.LINK
    Linkedin        : https://www.linkedin.com/in/erickvtorres/
    GitHub          : https://github.com/erickvtorres

.NOTES
    Creator         : Erick Torres do Vale
    Contact         : ericktorres@hotmail.com.br
    Date            : 2022-11-14
    LastUpdate      : 2022-11-14
    Version         : 0.1
        
.PARAMETER Identity
    Identity accept in 'Get-ADUser -Identity'

.PARAMETER Show
    -Show
    Write output the operations

    OldName      NewName Status  DisplayName
    ------------ ------  ------  -----------
    Julia Torres jtorres Success Julia Torres
    
.EXAMPLE

#>
#Requires -Modules ActiveDirectory

function Rename-CNwithSam {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact         = 'High'
    )]

    param (
        [Parameter(
            Position                        = 0,
            Mandatory                       = $true,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $Identity,

        [Parameter(
            Position                        = 1,
            Mandatory                       = $false,
            ValueFromPipeline               = $false,
            ValueFromPipelineByPropertyName = $false
        )]
        [switch]
        $Show
    )
    
    begin {
        [bool]$WriteLog = $false
        $LogFile        = $env:TEMP + "\Rename-CNwithSam.log"
        $Date           = Get-Date -Format 'dd-MM-yyyy'
    }
    
    process {
        try {
            $Object = Get-ADUser -Identity $Identity -Properties DisplayName
            Rename-ADObject -Identity $Object.DistinguishedName -NewName $Object.sAMAccountName
            $Status = 'Success'
            Write-Verbose -Message "Renamed $($Object.Name) to $($Object.sAMAccountName)"
        }
        catch [UnauthorizedAccessException] {
            Write-Warning -Message $_.Exception.Message
            $Creds = Get-Credential -Message 'Use an Account with Active Directory privileges'
            Rename-ADObject -Identity $Object.DistinguishedName -NewName $Object.sAMAccountName -Credential $Creds
            $Status = 'Success'
            Write-Verbose -Message "Renamed $($Object.Name) to $($Object.sAMAccountName)"
        }
        catch {
            [bool]$WriteLog = $true
            Write-Warning -Message $_.Exception.Message
            "$Date,$Identity,$($_.Exception.Message)" | Out-File -FilePath $LogFile -Append -Encoding utf8 -Force
            $Status = 'Failed'
        }        

        if ($Show){
            [PSCustomObject][ordered]@{
                OldName      = $Object.Name
                NewName      = $Object.sAMAccountName
                Status       = $Status
                DisplayName  = $Object.DisplayName 
            }
        }
    }
    
    end {
        if ($WriteLog -eq $true){
            Write-Output -InputObject "See logs at $LogFile"
        }
    }
}
