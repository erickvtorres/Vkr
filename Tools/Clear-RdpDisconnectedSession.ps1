<#
.SYNOPSIS
    Disconnect users with Disc/Disco status.

.DESCRIPTION
    Get logged users from remote computer using quser.exe, convert to CSV and force a logoff from disconnected users.

.LINK
    .Linkedin:      https://www.linkedin.com/in/erickvtorres/
    .GitHub:        https://github.com/erickvtorres

.NOTES
    .Creator:       Erick Torres do Vale
    .Contact:       ericktorres@hotmail.com.br
    .Date:          04/10/2023
    .LastUpdate     04/10/2023
    .Version:       0.0.1

.PARAMETER ComputerName
    One or more computer name

.PARAMETER OU
    Distinguished Name from OU

.PARAMETER DomainControllers
    Get all domain controllers available on domain

.PARAMETER Login
    Use this parameter to log out a specif user.

.EXAMPLE
    Clear-RdpDisconnectedSession -ComputerName VM01
    Clear-RdpDisconnectedSession -DomainControllers
    Clear-RdpDisconnectedSession -OU 'OU=ServersT1,DC=domain,dc=local'
    Clear-RdpDisconnectedSession -OU 'OU=ServersT1,DC=domain,dc=local' -Login erickvtorres
#>
#Requires -Modules ActiveDirectory

function Clear-RdpDisconnectedSession {
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    Param (
        [Parameter(
            Position          = 0,
            Mandatory         = $false,
            ValueFromPipeline = $true
        )]
        [array]
        $ComputerName,

        [Parameter(
            Position    = 0,
            Mandatory   = $false
        )]
        [string]
        $OU,

        [Parameter(
            Position  = 0,
            Mandatory = $false
        )]
        [Switch]
        $DomainControllers,

        [Parameter(
            Position  = 1,
            Mandatory = $false
        )]
        [string]
        $Login
    )

    begin {
        $Computers = New-Object -TypeName System.Collections.ArrayList
        switch ($PSBoundParameters.Keys) {
            ComputerName {
                try {
                    $ComputerName | ForEach-Object {
                        Get-ADComputer -Identity $_ | ForEach-Object {
                            Write-Verbose "Computer: $($_.DistinguishedName)"
                            [void]$Computers.Add($_)
                        }
                    }
                }
                catch {
                    Write-Warning $_.Exception.Message
                }
            }
            OU {
                try {
                    Get-ADComputer -Filter * -SearchBase $OU | ForEach-Object {
                        Write-Verbose "Computer: $($_.DistinguishedName)"
                        [void]$Computers.Add($_)
                    }
                }
                catch {
                    Write-Warning $_.Exception.Message
                }
            }
            DomainControllers {
                try {
                    Get-ADDomainController -Filter * | ForEach-Object {
                        Write-Verbose "Computer: $($_.ComputerObjectDN)"
                        [void]$Computers.Add($_)
                    }
                }
                catch {
                    Write-Warning $_.Exception.Message
                }
            }

            Default {
                Break
            }
        }
    }

    process {
        $Computers = $Computers.Name
        $Computers | ForEach-Object -Parallel {
            $Computer = $_
            $Login    = $USING:Login
            $Users    = quser /server:$_ 2>&1

            if ($Users.Count -gt 0) {
                $Regex = $Users | Select-Object -Skip 1 | ForEach-Object -Process { $_ -replace '\s{2,}', ',' }
                $Object = $Regex | ConvertFrom-Csv -Header Username, SessionId, State, IdleTime, LogonTime
                
                if ($Login){
                    $Session = $Object | Where-Object -FilterScript { $_.Username -eq $Login -and ($_.State -eq 'Disc' -or $_.State -eq 'Disco') }
                } else {
                    $Session = $Object | Where-Object -FilterScript { $_.State -eq 'Disc' -or $_.State -eq 'Disco' }
                }
                
                $Session | ForEach-Object {
                    logoff $_.SessionId /server:$Computer
                    [PSCustomObject]@{
                        ComputerName  = $Computer
                        Username      = $_.Username
                        IdleTime      = $_.IdleTime
                        LogonTime     = $_.LogonTime
                    } 
                }
            }
        }
    }

    end {
        $Computers = $Null
    }
}
