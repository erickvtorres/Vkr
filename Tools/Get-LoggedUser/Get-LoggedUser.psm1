<#
.SYNOPSIS
    Get logged users from computers

.DESCRIPTION
    Get logged users from computers converting result from quser.exe
    Get-LoggedUser get direct from ComputerName and Get-ADLoggedUser check if computers exists in AD,
    get all computer objects from OU or get all Domain Controllers.

    Get-ADLoggedUser requires ActiveDirectory module

.LINK
    .Linkedin:      https://www.linkedin.com/in/erickvtorres/
    .GitHub:        https://github.com/erickvtorres

.NOTES
    .Creator:       Erick Torres do Vale
    .Contact:       ericktorres@hotmail.com.br
    .Date:          2023-04-25
    .LastUpdate:    2023-04-27
    .Version:       0.0.1

.PARAMETER ComputerName
    Name of VMs or Computers to recover logged users, like computer01,computer02

.PARAMETER OU
    DistinguishedName from OU with desired servers or computers

.PARAMETER DomainControllers
    Get all domain controllers from domain

.EXAMPLE
    Get-LoggedUser
    Get-LoggedUser -ComputerName VMACHINE01,VMACHINE02,VMACHINE03

    Get-ADLoggedUser -OU 'OU=Servers,DC=vkr,DC=inc'
    Get-ADLoggedUser -DomainControllers
#>

function Get-LoggedUser {
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    param (
        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'ComputerName'
        )]
        [array]$ComputerName
    )
    
    begin {
        $defaultDisplaySet         = 'ID', 'Username', 'SessionName', 'State'
        $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
        $PSStandardMembers         = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
        $DateRegex                 = '[0-9]{2}\W{1}[0-9]{2}\W{1}[0-9]{4}\s{1}[0-9]{2}\W[0-9]{2}'

        if (-Not $ComputerName){$ComputerName = $env:COMPUTERNAME}
    }
    
    process {
        $ComputerName | ForEach-Object {
            $Users  = quser /server:$_ 2>&1
            if ($Users[0] -like 'Error*'){return}

            $Regex  = $Users | Select-Object -Skip 1 | ForEach-Object -Process { $_ -replace '\s{2,}', ',' }
            $Regex | ForEach-Object {
                $Object = $_.Split(',')
                $Result = [PSCustomObject]@{
                    Username    = $Object[0] -replace '>' -replace ' '
                    SessionName = if ($Object[1] -eq 'console' -or $Object[1] -like 'rdp-tcp*'){$Object[1]} else {'no-session'}
                    ID          = if ($Object[2] -match '[0-9]'){$Object[2]} else {$Object[1]}    
                    State       = if ($Object[3] -match '[A-Za-z]'){$Object[3]} else {$Object[2]}
                    IdleTime    = if ($Object[4] -notmatch $DateRegex){$Object[4]} else {$Object[3]}
                    LogonTime   = if ($Object[5]) {$Object[5]} else {$Object[4]}
                }

                $Result.PSObject.TypeNames.Insert(0,'User.Information')
                $Result | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                $Result
            }
        }
    }
    
    end {
        $List > $null
    }
}

function Get-ADLoggedUser {
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    param (
        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'ComputerName'
        )]
        [array]$ComputerName,

        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'OU'
        )]
        [string]$OU,

        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'DCs'
        )]
        [switch]$DomainControllers
    )
    
    begin {
        $defaultDisplaySet         = 'ID', 'Username', 'SessionName', 'State'
        $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
        $PSStandardMembers         = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

        $DateRegex = '[0-9]{2}\W{1}[0-9]{2}\W{1}[0-9]{4}\s{1}[0-9]{2}\W[0-9]{2}'
        $Computers = New-Object -TypeName System.Collections.ArrayList
        switch ($PSBoundParameters.Keys) {
            ComputerName {
                try {
                    $ComputerName | ForEach-Object {
                        Get-ADComputer -Identity $_ | ForEach-Object {
                            Write-Verbose "Computer: $($_.DistinguishedName)"
                            [void]$Computers.Add($_.Name)
                        }
                    }
                }
                catch {
                    Write-Warning $_.Exception.Message
                    break
                }
            }

            OU {
                try {
                    Get-ADComputer -Filter {Enabled -eq $true} -SearchBase $OU | ForEach-Object {
                        Write-Verbose "Computer: $($_.DistinguishedName)"
                        [void]$Computers.Add($_.Name)
                    }
                }
                catch {
                    Write-Warning $_.Exception.Message
                    break
                }
            }

            DomainControllers {
                try {
                    Get-ADDomainController -Filter * | ForEach-Object {
                        Write-Verbose "Computer: $($_.ComputerObjectDN)"
                        [void]$Computers.Add($_.Name)
                    }
                }
                catch {
                    Write-Warning $_.Exception.Message
                    break
                }
            }

            Default {
                break
            }
        }
    }
    
    process {
        $Computers | ForEach-Object {
            $Users  = quser /server:$_ 2>&1
            if ($Users[0] -like 'Error*'){return}
            
            $Regex  = $Users | Select-Object -Skip 1 | ForEach-Object -Process { $_ -replace '\s{2,}', ',' }
            $Regex | ForEach-Object {
                $Object = $_.Split(',')
                $Result = [PSCustomObject]@{
                    Username    = $Object[0] -replace '>' -replace ' '
                    SessionName = if ($Object[1] -eq 'console' -or $Object[1] -like 'rdp-tcp*'){$Object[1]} else {'no-session'}
                    ID          = if ($Object[2] -match '[0-9]'){$Object[2]} else {$Object[1]}    
                    State       = if ($Object[3] -match '[A-Za-z]'){$Object[3]} else {$Object[2]}
                    IdleTime    = if ($Object[4] -notmatch $DateRegex){$Object[4]} else {$Object[3]}
                    LogonTime   = if ($Object[5]) {$Object[5]} else {$Object[4]}
                }

                $Result.PSObject.TypeNames.Insert(0,'User.Information')
                $Result | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                $Result
            }
        }
    }
    
    end {
        $Computers > $null
    }
}
