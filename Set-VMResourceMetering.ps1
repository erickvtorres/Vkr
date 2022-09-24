<#
    .SYNOPSIS
    Gather VMs Resource Metering information, enable or disable.

    .LINK
    Linkedin:      https://www.linkedin.com/in/erickvtorres/
    GitHub:        https://github.com/erickvtorres/Vkr

    .NOTES
    Date:          2022-02-03
    LastUpdate:    2022-09-23
    Version:       1.0

    .EXAMPLE
    Set-VMResourceMetering -Status    # Get Resource Metering from VMs
    Set-VMResourceMetering -Enable    # Enable Resource Metering
    Set-VMResourceMetering -Disable   # Disable Resource Metering
#>

function Set-VMResourceMetering {
    [CmdletBinding(DefaultParameterSetName = 'Status')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Status')]
        [switch] $Status,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Enable')]
        [switch] $Enable,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Disable')]
        [switch] $Disable
    )
    
    begin {
        $ClusterName = Read-Host "Hyper-V Cluster Name"
        $Nodes = (Get-ClusterNode -Cluster $ClusterName).Name
        $VirtualMachines = @()
        $VirtualMachinesHashTable = @()
        $Export = "C:\Reports"

        if (-Not (Test-Path $Export)) {
            Write-Host "$([char]0x203A) Creating $($Export): " -NoNewline
            try {
                New-Item -ItemType Directory -Path $Export -Force | Out-Null
                Write-Host "Done" -ForegroundColor Green
            }
            catch {
                Write-Host $_.Exception.Message -ForegroundColor Red
            }
        }
    }
    
    process {
        
        Write-Host "$([char]0x203A) Gathering VMs: " -NoNewline
        foreach ($Node in $Nodes) {
            try {
                $VirtualMachines += Get-VM -ComputerName $Node
            }
            catch {
                Write-Host $_.Exception.Message
                Break
            }
        } #Gathering VMs

        Write-Host "$($VirtualMachines.Count) found" -ForegroundColor Green
        $VirtualMachines = $VirtualMachines | Sort-Object ComputerName,VMName

        if ($Status) {
            $Counter = 1
            foreach ($VMItem in $VirtualMachines) {
                Write-Progress -Activity "Gathering VMs details from Node $($VMItem.ComputerName)" -Status "Step $($Counter) of $($VirtualMachines.Count) complete"`
                    -CurrentOperation "Current operation: $($VMItem.VMName)" -PercentComplete (($Counter / $VirtualMachines.Count) * 100)
                $Counter++

                $VirtualMachinesHashTable += [PSCustomObject]@{
                    VMName   = $VMItem.VMName
                    VMId     = $VMItem.VMId
                    Metering = $VMItem.ResourceMeteringEnabled
                    Uptime   = $VMItem.Uptime
                    Status   = $VMItem.Status
                    State    = $VMItem.State
                    Node     = $VMItem.ComputerName
                }
            } #Hastable
            Write-Progress -Activity "Completed" -Completed

            $StatusFileName = "$($Export)\VMsResourceMetering-$(Get-Date -Format dd-MM-yyyy).xlsx"
            Write-Host "$([char]0x203A) Exporting to $($StatusFileName)"
            $VirtualMachinesHashTable | Export-Excel $StatusFileName -Append -WorksheetName 'Status' -AutoSize -FreezeTopRow -TableStyle Medium13
        }

        if ($Enable) {
            $Counter = 1
            $Success = 0
            $Fail    = 0
            foreach ($VMItem in $VirtualMachines) {
                Write-Progress -Activity "Enabling VMs Resource Metering from Node $($VMItem.ComputerName)" -Status "Step $($Counter) of $($VirtualMachines.Count) complete"`
                -CurrentOperation "Current operation: $($VMItem.VMName)" -PercentComplete (($Counter / $VirtualMachines.Count) * 100)
                $Counter++

                try {
                    Enable-VMResourceMetering -VMName $VMItem.VMName -ComputerName $VMItem.ComputerName
                    Reset-VMResourceMetering -VMName $VMItem.VMName -ComputerName $VMItem.ComputerName
                    $Success++
                }
                catch {
                    Write-Warning "$([char]0x203A) $($VMItem.VMName) - $($_.Exception.Message)"
                    $Erro = "$(Get-Date -Format dd-MM-yyyy),$($VMItem.VMName),$($VMItem.ComputerName),$($_.Exception.Message)"
                    $Erro | Out-File "$Export\Enable-VMResourceMetering-Log.log" -Append
                    $Fail++
                }
            }
        }

        if ($Disable) {
            $Counter = 1
            $Success = 0
            $Fail    = 0
            foreach ($VMItem in $VirtualMachines) {
                Write-Progress -Activity "Disabling VMs Resource Metering from Node $($VMItem.ComputerName)" -Status "Step $($Counter) of $($VirtualMachines.Count) complete"`
                -CurrentOperation "Current operation: $($VMItem.VMName)" -PercentComplete (($Counter / $VirtualMachines.Count) * 100)
                $Counter++

                try {
                    Disable-VMResourceMetering -VMName $VMItem.VMName -ComputerName $VMItem.ComputerName
                    Reset-VMResourceMetering -VMName $VMItem.VMName -ComputerName $VMItem.ComputerName
                    $Success++
                }
                catch {
                    Write-Warning "$($VMItem.VMName) - $($_.Exception.Message)"
                    $Erro = "$(Get-Date -Format dd-MM-yyyy),$($VMItem.VMName),$($VMItem.ComputerName),$($_.Exception.Message)"
                    $Erro | Out-File "$Export\Disable-VMResourceMetering-Log.log" -Append
                    $Fail++
                }
            }
        }
    }
    
    end {
        if ($Status){
            Invoke-Expression "explorer '/select,$StatusFileName'"
        }

        if ($Enable){
            Write-Host "$([char]0x203A) Enabled Resource Metering for $($VirtualMachines.Count) virtual machines from Cluser $($ClusterName)"
            if ($Fail -ge 1){
                Write-Host "$([char]0x203A) $($Fail) virtual machines has not enabled, see log - $Export\Enable-VMResourceMetering-Log.log" -ForegroundColor Red
            }
        }

        if ($Disable){
            Write-Host "$([char]0x203A) Disabled Resource Metering for $($VirtualMachines.Count) virtual machines from Cluser $($ClusterName)"
            if ($Fail -ge 1){
                Write-Host "$([char]0x203A) $($Fail) virtual machines has not disabled, see log $Export\Enable-VMResourceMetering-Log.log" -ForegroundColor Red
            }
        }
    }
}
