<#
.SYNOPSIS
    Move computer in a simple way

.DESCRIPTION
    Move AD Computer object to desired OU without need to get DistinguishedName and disable 'ProtectedFromAccidentalDeletion'.
    If use Import-Csv, the parameters ComputerName and Target must be in ther first line or explict in Import-CSV -Header

.LINK
    Linkedin        : https://www.linkedin.com/in/erickvtorres/
    GitHub          : https://github.com/erickvtorres

.NOTES
    Creator         : Erick Torres do Vale
    Contact         : ericktorres@hotmail.com.br
    Date            : 2022-11-14
    LastUpdate      : 2022-11-14
    Version         : 0.1
        
.PARAMETER ComputerName
    Identity accept in 'Get-ADComputer -Identity'

.PARAMETER Target
    Must be the 'DistinguishedName'
    'OU=TI,OU=Company,DC=domain,DC=local'

.PARAMETER Show
    -Show
    Write output the operations
    
    ComputerName Status Target                                                                              
    ------------ ------ ------
    COMPUTER1    Moved  OU=TI,OU=Company,DC=domain,DC=local
    COMPUTER2    Moved  OU=TI,OU=Company,DC=domain,DC=local
    COMPUTER3    Failed OU=TI,OU=Company,DC=domain,DC=local

.PARAMETER Confirm
    -Confirm:$false to force bypass ProtectedFromAccidentalDeletion
    
.EXAMPLE
    Move-ADComputer -Identity <computername> -Target <ou-distinguishedName>

    Move-ADComputer -Identity COMPUTER1 -Target 'OU=TI,OU=Company,DC=domain,DC=local' -Confirm:$false

    @('COMPUTER1','COMPUTER2') | Move-ADComputer -Target 'OU=TI,OU=Company,DC=domain,DC=local' -Confirm:$false

    Import-Csv -Path C:\Temp\Computers.csv | Move-ADComputer

    Import-Csv -Path C:\Temp\Computers.csv | Move-ADComputer -Show

    $Computer | Move-ADComputer -Target 'OU=TI,OU=Company,DC=domain,DC=local'
#>

function Move-ADComputer {
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
        $ComputerName,

        [Parameter(
            Position                        = 1,
            Mandatory                       = $true,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateScript({
            Get-ADOrganizationalUnit -Identity $_
        })]
        [string]
        $Target,

        [Parameter(
            Position                        = 2,
            Mandatory                       = $false,
            ValueFromPipeline               = $false,
            ValueFromPipelineByPropertyName = $false
        )]
        [switch]
        $Show
    )
    
    begin {
        [bool]$WriteLog = $false
        $LogFile        = $env:TEMP + "\Mode-ADComputer.log"
        $Date           = Get-Date -Format 'dd-MM-yyyy'
    }
    
    process {
        try {
            $Object = Get-ADComputer -Identity $ComputerName -Properties ProtectedFromAccidentalDeletion
            Move-ADObject -Identity $Object.DistinguishedName -TargetPath $Target -ErrorAction Stop
            $Status = 'Moved'
            Write-Verbose -Message "Moved $ComputerName to $Target"
        }
        catch [UnauthorizedAccessException] {
            if ($PSCmdlet.ShouldProcess($Object.Name,'Bypass ProtectedFromAccidentalDeletion')) {
                Set-ADObject -Identity $Object.DistinguishedName -ProtectedFromAccidentalDeletion $false
                Move-ADObject -Identity $Object.DistinguishedName -TargetPath $Target
                Get-ADComputer -Identity $ComputerName | Set-ADObject -ProtectedFromAccidentalDeletion $true
            }
            Write-Verbose -Message "Moved $ComputerName to $Target | Protection bypass"
            $Status = 'Moved'
        }
        catch {
            [bool]$WriteLog = $true
            Write-Warning -Message $_.Exception.Message
            "$Date,$ComputerName,$($_.Exception.Message)" | Out-File -FilePath $LogFile -Append -Encoding utf8 -Force
            $Status = 'Failed'
        }

        if ($Show){
            [PSCustomObject][ordered]@{
                ComputerName = $ComputerName
                Status       = $Status
                Target       = $Target
            }
        }
    }
    
    end {
        if ($WriteLog -eq $true){
            Write-Output -InputObject "See logs at $LogFile"
        }
    }
}
