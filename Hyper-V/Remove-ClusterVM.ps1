<#
.SYNOPSIS
    Remove VM resources and files from Failover Cluster Hyper-V

.DESCRIPTION
    Delete virtual machine from failover cluster, hyper-v node and all configuration files from cluster storage.
    The files must be inside a folder with the same name as VMName.

.LINK
    Linkedin    : https://www.linkedin.com/in/erickvtorres/
    GitHub      : https://github.com/erickvtorres

.NOTES
    Creator     : Erick Torres do Vale
    Contact     : ericktorres@hotmail.com.br
    Date        : 2023-02-08
    LastUpdate  : 2023-02-10
    Version     : 0.0.1

.PARAMETER Delete
    Will only remove resources from cluster and hyper-v node, keeping files on cluster storage.

.PARAMETER HardDelete
    Remove everything.

.EXAMPLE
    Remove-ClusterVM -Cluster <server> -VMName <vmname> -Action Delete
    Remove-ClusterVM -Cluster <server> -VMName <vmname> -Action HardDelete
    Remove-ClusterVM -Cluster <server> -VMName <vmname> -Action HardDelete -Log
    Remove-ClusterVM -Cluster <server> -VMName <vmname> -Action HardDelete -Log -Verbose
#>

#Requires -Modules Hyper-V
Import-Module Hyper-V

function Remove-ClusterVM {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High'
    )]
    param (
        [Parameter(
            Position                        = 0,
            Mandatory                       = $false,
            ValueFromPipeline               = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $Cluster,

        [Parameter(
            Position                        = 1,
            Mandatory                       = $true,
            ValueFromPipeline               = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $VMName,

        [Parameter(
            Position                        = 2,
            Mandatory                       = $true,
            ValueFromPipeline               = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateSet('Delete', 'HardDelete')]
        [string]
        $Action,

        [Parameter(
            Position  = 3,
            Mandatory = $False
        )]
        [switch]
        $Log
    )
    
    begin {
        if ($env:COMPUTERNAME -eq $Cluster) {
            $Machine = 'Local'
        } elseif (-Not ($Cluster)){
            $Machine = 'Local'
        } else {
            $Machine = 'Remotely'
        }
        $LogMessage = New-Object -TypeName System.Collections.ArrayList
        [void]$LogMessage.Add("[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Remove-CusterVM is running $Machine")
    }
    
    process {
        $VMName | ForEach-Object {
            try {
                $VM = Get-VM -ComputerName $Cluster -VMName $PSItem -ErrorAction Stop
                Write-Verbose -Message "Found $($VM.VMName) at $($VM.ComputerName)"
                [void]$LogMessage.Add("[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] $($VM.VMName) Found virtual machine at $($VM.ComputerName)")

                if ($VM.State -eq 'Running'){
                    if ($PSCmdlet.ShouldProcess("$PSItem", "Shutting Down the virtual machine")) {
                        try {
                            Stop-VM -ComputerName $Cluster -Name $PSItem 
                            Write-Verbose -Message "$PSItem shutdown!"
                            [void]$LogMessage.Add("[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] $($VM.VMName): Shutdown virtual machine")
                        }
                        catch {
                            Write-Warning -Message $_.Exception.Message
                            if ($PSCmdlet.ShouldContinue('Force Turn Off VM. This operation is equivalent to disconnecting the power from the virtual machine, and can result in loss of unsaved data.')){
                                Stop-VM -ComputerName $Cluster -Name $PSItem -TurnOff
                                Write-Warning -Message "$PSItem turned off!"
                            }
                        } 
                    }
                }
            }
            catch {
                Write-Warning -Message $_.Exception.Message
                [void]$LogMessage.Add("[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] $($VM.VMName): Failed to shutdown virtual machine")
                continue
            }

            if ($Action -eq 'Delete' -or $Action -eq 'HardDelete') {
                try {
                    Remove-ClusterGroup -Cluster $Cluster -VMId $VM.VMId -RemoveResources -Force -ErrorAction Stop
                    Write-Verbose -Message 'Resource have been successfully removed from the Cluster'
    
                    Remove-VM -ComputerName $VM.ComputerName -VMName $PSItem -Force -ErrorAction Stop
                    Write-Verbose -Message 'Resource have been successfully removed from the Hyper-V Node'

                    [void]$LogMessage.Add("[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] $($VM.VMName): Virtual machine have been successfully removed from cluster and hyper-v node")

                    if ($Action -eq 'HardDelete' -and $PSCmdlet.ShouldProcess("$VMName", "HardDelete. Will destroy all files from VM, this action can not be undone.")) {
                        $Path = $VM.Path.split('\')[-1]
                        if ($PSItem -eq $Path) {
                            if ($Machine -eq 'Local') {
                                Remove-Item -Path $VM.Path -Recurse -Force -WhatIf
                                Write-Verbose -Message 'Resource have been successfully removed from the ClusterStorage'
                            }
                            else {
                                $Files = $VM.Path -replace 'C:', "\\$($VM.ComputerName)\C$"
                                Remove-Item -Path $Files -Recurse -Force
                                Write-Verbose -Message 'Resource have been successfully removed from the ClusterStorage'
                            }

                            [void]$LogMessage.Add("[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] $($VM.VMName): Removed all files from cluster storage")
                        }
                        else {
                            Write-Warning -Message "Configuration files must be manually removed, the path may contains more files that do not belong to this virtual machine`nLOCATION: $($VM.Path)"
                            [void]$LogMessage.Add("[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] $($VM.VMName): Configuration files must be manually removed")
                        }
                    }
                }
                catch {
                    Write-Warning -Message $_.Exception.Message
                    [void]$LogMessage.Add("[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] $($VM.VMName): Failed to delete virtual machine: $($_.Exception.Message)")
                }
            }
        }        
    }
    
    end {
         if ($Log){
            [void]$LogMessage.Add("[$(Get-Date -Format 'yyyy-MM-dd HH-mm-ss')] Remove-CusterVM finished")
            Out-File -FilePath "$env:TEMP\Remove-ClusterVM.log" -Append -Force -InputObject $LogMessage
            Invoke-Item -Path "$env:TEMP\Remove-ClusterVM.log"
         }
    }
}
