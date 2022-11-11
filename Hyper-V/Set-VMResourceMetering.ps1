<#
.SYNOPSIS
    Gather VMs Resource Metering information, enable, disable or reset.

.DESCRIPTION
    Resource Metering gets the hardware average usage from Virtual Machines.
    Important - VMs needs to be configured with Dynamic Memory.

.LINK
    Linkedin    : https://www.linkedin.com/in/erickvtorres/
    GitHub      : https://github.com/erickvtorres

.NOTES
    Creator     : Erick Torres do Vale
    Contact     : ericktorres@hotmail.com.br
    Date        : 2022-02-03
    LastUpdate  : 2022-11-11
    Version     : 1.1

.EXAMPLE
    Set-VMResourceMetering -ComputerName <server> -HypervModes <FailoverClustering|StandaloneServer> -Status
    Set-VMResourceMetering -ComputerName <server> -HypervModes <FailoverClustering|StandaloneServer> -Action <Enable|Disable|Reset>
#>

function Set-VMResourceMetering {
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    param (
        [parameter(
            Mandatory = $true,
            Position = 0,
            ParameterSetName = 'ComputerName'
        )]
        [string]
        $ComputerName,

        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [ValidateSet('FailoverClustering', 'StandaloneServer')]
        [string]
        $HypervMode,

        [Parameter(
            Mandatory = $false,
            Position = 2
        )]
        [switch]
        $Status,

        [Parameter(
            Mandatory = $false,
            Position = 2
        )]
        [ValidateSet('Enable', 'Disable', 'Reset')]
        [string]
        $Action
    )
    
    begin {
        $VMs = New-Object -TypeName System.Collections.ArrayList
        $excptmsg = "$(Get-Date -Format dd-MM-yyyy),$($_.VMName),$($_.Node),$($_.Exception.Message)"

        switch ($PSBoundParameters.ContainsKey('HypervMode')) {
            FailoverClustering { 
                try {
                    Get-Cluster -Name $ComputerName -ErrorAction Stop | Out-Null
                    $Nodes = (Get-ClusterNode -Cluster $ComputerName).Name
                    Write-Verbose -Message "HypervMode: Failover Clustering, gathering nodes"
                }
                catch {
                    Write-Warning $_.Exception.Message
                }
            }
            StandaloneServer { 
                try {
                    $Nodes = (Get-VMHost -ComputerName $ComputerName -ErrorAction Stop).Name
                    Write-Verbose -Message "HypervMode: Standalone Server"
                }
                catch {
                    Write-Warning $_.Exception.Message
                }
            }
            Default { break }
        }
    }
    
    process {
        if ($PSBoundParameters.ContainsKey('Status')) {
            Write-Verbose -Message "Status: Gathering status from VMs"
            $Nodes | ForEach-Object {
                Get-VM -ComputerName $ComputerName | ForEach-Object {
                    [pscustomobject]@{
                        VMName     = $_.VMName
                        Node       = $_.ComputerName
                        Metering   = $_.ResourceMeteringEnabled
                        RAMDynamic = $_.DynamicMemoryEnabled
                        Uptime     = $_.Uptime
                        Status     = $_.Status
                        State      = $_.State
                    }
                }
            }
        }

        if ($PSBoundParameters.ContainsKey('Action')) {
            $Nodes | ForEach-Object {
                Get-VM -ComputerName $ComputerName | ForEach-Object {
                    $item = [pscustomobject]@{
                        VMName   = $_.VMName
                        Node     = $_.ComputerName
                        Metering = $_.ResourceMeteringEnabled
                        Uptime   = $_.Uptime
                        Status   = $_.Status
                        State    = $_.State
                    }
                    [void]$VMs.Add($item)
                }
            }

            $Fail = 0
            $VMs = $VMs | Sort-Object Node,VMName
            switch ($Action) {
                Enable {
                    $VMs | ForEach-Object{
                        try {
                            Enable-VMResourceMetering -ComputerName $_.Node -VMName $_.VMName
                            Write-Verbose -Message "Running action 'Enable' at $($_.VMName) on $($_.Node)"
                        }
                        catch {
                            Write-Warning "$([char]0x203A) $($_.VMName) - $($_.Exception.Message)"
                            $excptmsg | Out-File "$env:TEMP\Set-VMResourceMetering-Log.log" -Append
                            $Fail++
                        }
                    }
                }
                Disable { 
                    $VMs | ForEach-Object{
                        try {
                            Disable-VMResourceMetering -ComputerName $_.Node -VMName $_.VMName
                            Write-Verbose -Message "Running action 'Disable' at $($_.VMName) on $($_.Node)"
                        }
                        catch {
                            Write-Warning "$([char]0x203A) $($_.VMName) - $($_.Exception.Message)"
                            $excptmsg | Out-File "$env:TEMP\Set-VMResourceMetering-Log.log" -Append
                            $Fail++
                        }
                    }
                }
                Reset {
                    $VMs | ForEach-Object{
                        try {
                            Reset-VMResourceMetering -ComputerName $_.Node -VMName $_.VMName
                            Write-Verbose -Message "Running action 'Reset' at $($_.VMName) on $($_.Node)"
                        }
                        catch {
                            Write-Warning "$([char]0x203A) $($_.VMName) - $($_.Exception.Message)"
                            $excptmsg | Out-File "$env:TEMP\Set-VMResourceMetering-Log.log" -Append
                            $Fail++
                        }
                    }
                }
                Default { 
                    Break
                }
            }
        }
    }
    
    end {
        if ($Fail -gt 0) {
            Write-Output "Finished with $Fail errors | Action runned at $($VMs.Count)"
            Write-Output "See log at $env:TEMP\Set-VMResourceMetering-Log.log"
        }
    }
}
