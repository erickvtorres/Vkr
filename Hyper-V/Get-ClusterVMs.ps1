<#
.SYNOPSIS
    Export VM resources from Failover Cluster Hyper-V

.DESCRIPTION
    Gather virtual machines hardware, network, operating system, status ans configuration.
    All objects are changed to export to xlsx/csv without need to convert array to string.
    A better way to export this information, is using ImportExcel Module with bellow parameters

    $Excel = @{
        Path               = 'C:\Reports\Cluster.xlsx'
        WorksheetName      = 'VMs'
        Append             = $true
        TitleBold          = $true
        AutoSize           = $true
        AutoFilter         = $true
        FreezeTopRow       = $true
        TableStyle         = 'Light8'
        NoNumberConversion = '*'
    }

.LINK
    Linkedin    : https://www.linkedin.com/in/erickvtorres/
    GitHub      : https://github.com/erickvtorres

.NOTES
    Creator     : Erick Torres do Vale
    Contact     : ericktorres@hotmail.com.br
    Date        : 2021-12-14
    LastUpdate  : 2022-11-10
    Version     : 1.6

.EXAMPLE

    Get-ClusterVMs -ComputerName <server>
    Get-ClusterVMs -ComputerName <server> -VMName <vmname>
    Get-ClusterVMs -ComputerName <server> | Select-Object Name,Memory,vCPU,VhdSize,Uptime
    Get-ClusterVMs -ComputerName <server> | Export-CSV -Path C:\Temp -Append
    Get-ClusterVMs -ComputerName <server> | Export-Excel C:\Repors\$ComputerName.xlsx -WorksheetName $ComputerName -Append -TitleBold -AutoSize -AutoFilter -FreezeTopRow -TableStyle Light8 -NoNumberConversion *
#>

#Requires -PSEdition Core -Modules ActiveDirectory,Hyper-V
Import-Module ActiveDirectory, Hyper-V

function Get-ClusterVMs {
    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ParameterSetName = 'ComputerName'
        )]
        [string]
        $ComputerName,

        [Parameter(
            Mandatory = $false,
            Position = 1
        )]
        [string]
        $VMName
    )
    
    begin {
        $VMs = New-Object -TypeName System.Collections.ArrayList

        try {
            Get-Cluster -Name $ComputerName -ErrorAction Stop | Out-Null
            $ClusterNodes = (Get-ClusterNode -Cluster $ComputerName).Name
        }
        Catch {
            Write-Warning $_.Exception.Message
            Break
        }

        if ($PSBoundParameters.ContainsKey('VMName')) {
            try {
                Get-VM -ComputerName $ComputerName -VMName $VMName -ErrorAction Stop | ForEach-Object {
                    $Query = [PSCustomObject]@{
                        Name = $_.VMName
                        Node = $_.ComputerName
                    }
                    [void]$VMs.Add($Query)
                }
            }
            catch {
                Write-Warning $_.Exception.Message
                Break
            }
        }
        else {
            try {
                $SyncNodes = [System.Collections.Hashtable]::Synchronized(@{i = 1 })
                $ClusterNodes | ForEach-Object -Parallel {
                    $Node = $_
                    $Nodes = $USING:ClusterNodes
                    $Progress = $USING:SyncNodes
                    $ComputerName = $USING:ComputerName
                    $VMs = $USING:VMs
                    $Count = $Progress.i
                    $Progress.i++

                    $ProgressBegin = @{
                        Id               = 1
                        Activity         = "Working on $ComputerName"
                        Status           = "$Node | $Count of $($Nodes.Count)"
                        CurrentOperation = $Node
                        PercentComplete  = (($Count / $Nodes.Count) * 100)
                    }

                    Write-Progress @ProgressBegin

                    Get-VM -ComputerName $Node | ForEach-Object {
                        $List = [PSCustomObject]@{
                            Name = $_.VMName
                            Node = $Node
                        }
                        [void]$VMs.Add($List)
                    }
                }
                $VMs = $VMs | Sort-Object Node, Name
            }
            catch {
                Write-Warning $_.Exception.Message
                Break
            }
            Write-Progress -Id 1 -Activity 'Completed' -Status 'Ready' -Completed
        }
    }
    
    process {
        $Sync = [System.Collections.Hashtable]::Synchronized(@{i = 1 })
        $VMs | ForEach-Object -Parallel {
            $Items = $USING:VMs
            $Progress = $USING:Sync
            $Count = $Progress.i
            $Percent = ($Count / $Items.Count) * 100
            $Percent = '{0:N2}' -f ($Percent)
            $Progress.i++


            if (-Not ($PSBoundParameters.ContainsKey('Name'))) {
                $ProgressProcess = @{
                    Id               = 2
                    Activity         = "Working on $($_.Node)"
                    Status           = "$($_.Name) | $Count of $($Items.Count) | $Percent%"
                    CurrentOperation = $($_.Node)
                    PercentComplete  = (($Count / $Items.Count) * 100)
                }
                Write-Progress @ProgressProcess
            }

            $GetVM = Get-VM -ComputerName $($_.Node) -VMName $($_.Name)
            
            $OSName = New-Object -TypeName pscustomobject
            try {
                Get-ADComputer -Identity $($_.Name) -Properties operatingSystem, operatingSystemVersion -ErrorAction Stop | ForEach-Object {
                    $OSName | Add-Member -MemberType NoteProperty -Name 'Name' -Value $_.operatingSystem
                    $OSName | Add-Member -MemberType NoteProperty -Name 'Version' -Value $_.operatingSystemVersion
                }
            }
            catch {
                $OSName | Add-Member -MemberType NoteProperty -Name 'Name' -Value 'Not found'
                $OSName | Add-Member -MemberType NoteProperty -Name 'Version' -Value 'Not found'
            }
            
            $Network = New-Object -TypeName pscustomobject
            $GetVM | ForEach-Object {
                $Network | Add-Member -MemberType NoteProperty -Name 'IPAddresses' -Value ($Ip = [array]$Ip += ($_.NetworkAdapters.IPAddresses | Where-Object { $_ -notmatch '::' } )) -Force
                $Network | Add-Member -MemberType NoteProperty -Name 'SwitchName' -Value ($Switch = [array]$Switch += $_.NetworkAdapters.SwitchName) -Force
            }
            Get-VMNetworkAdapterVlan -ComputerName $($_.Node) -VMName $($_.Name) | ForEach-Object {
                $Network | Add-Member -MemberType NoteProperty -Name 'AccessVlanId' -Value ($VlanId = [array]$VlanId += $_.AccessVlanId) -Force
                $Network | Add-Member -MemberType NoteProperty -Name 'OperationMode' -Value ($OperMode = [array]$OperMode += $_.OperationMode) -Force
            }
            
            Get-VMNetworkAdapter -ComputerName $($_.Node) -VMName $($_.Name) | ForEach-Object {
                $Network | Add-Member -MemberType NoteProperty -Name 'NetworkAdapter' -Value ($Adapter = [array]$Adapter += $_.Name) -Force
                $Network | Add-Member -MemberType NoteProperty -Name 'MacAddress' -Value ($Mac = [array]$Mac += $_.MacAddress -replace ('..(?!$)', '$&:')) -Force
            }

            $VHD = New-Object -TypeName pscustomobject
            Get-VHD -ComputerName $($_.Node) -VMId $GetVM.VMId | ForEach-Object {
                $VHD | Add-Member -MemberType NoteProperty -Name 'Size' -Value ($Size = [array]$Size += ('{0:N0}' -f ($_.Size / 1024Mb))) -Force
                $VHD | Add-Member -MemberType NoteProperty -Name 'VhdFormat' -Value ($Format = [array]$Format += $_.VhdFormat) -Force
                $VHD | Add-Member -MemberType NoteProperty -Name 'VhdType' -Value ($Type = [array]$Type += $_.VhdType) -Force
            }
            
            [PSCustomObject]@{
                Name                    = $GetVM.VMName
                State                   = $GetVM.State
                RAM                     = '{0:N0}' -f ($GetVM.MemoryStartup / 1024Mb)
                MemoryAssigned          = '{0:N0}' -f ($GetVM.MemoryAssigned / 1024Mb)
                vCPU                    = $GetVM.ProcessorCount
                vCPUUsage               = $GetVM.CPUUsage
                OSName                  = $OSName.Name
                OSVersion               = $OSName.Version
                Uptime                  = $GetVM.Uptime
                VhdSize                 = ForEach-Object { $VHD.Size -join ',' }
                VhdFormat               = ForEach-Object { $VHD.VhdFormat -join ',' }
                VhdType                 = ForEach-Object { $VHD.VhdType -join ',' }
                IPAddresses             = ForEach-Object { $Network.IPAddresses -join ',' }
                SwitchName              = ForEach-Object { $Network.SwitchName -join ',' }
                AccessVlanId            = ForEach-Object { $Network.AccessVlanId -join ',' }
                OperationMode           = ForEach-Object { $Network.OperationMode -join ',' }
                NetworkAdapter          = ForEach-Object { $Network.NetworkAdapter -join ',' }
                MacAddress              = ForEach-Object { $Network.MacAddress -join ',' }
                Status                  = $GetVM.Status
                Generation              = $GetVM.Generation
                Version                 = $GetVM.Version
                DynamicMemoryEnabled    = $GetVM.DynamicMemoryEnabled
                IsClustered             = $GetVM.IsClustered
                ResourceMeteringEnabled = $GetVM.ResourceMeteringEnabled
                VMId                    = $GetVM.VMId
                CheckpointFileLocation  = $GetVM.CheckpointFileLocation
                ConfigurationLocation   = $GetVM.ConfigurationLocation
            }
        }
    }
    
    end {
        Write-Progress -Id 2 -Activity "Working on $($_.Node)" -Status 'Ready' -Completed
        $VMs = $null
    }
}
