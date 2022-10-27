<#
.DESCRIPTION

Gather basics informations from Windows VMs hosted on Hyper-V and Cluster Hyper-V.

.LINK

    .Linkedin:      https://www.linkedin.com/in/erickvtorres/
    .GitHub:        https://github.com/erickvtorres

.NOTES

Powershell [7] Core  required.
Depending on your Windows Version, the Hyper-V module could be incompatible whit eldest Windows Servers.
To change values with ; to array, remove -join ';'

    .Creator:       Erick Torres do Vale
    .Contact:       ericktorres@hotmail.com.br
    .Date:          2021-12-14
    .LastUpdate:    2022-10-27
    .Version:       1.0

.EXAMPLE

    Get-ClusterVMs -Server CLUSTERNAME
    Get-ClusterVMs -Server CLUSTERNAME -Name VMNAME
    Get-ClusterVMs -Server CLUSTERNAME -Export C:\Temp\ClusterVMs.xlsx  # Include All Properties
    Get-ClusterVMs -Server CLUSTERNAME | Select-Object Name,MemoryAssigned,vCPUs,DiskSize,Uptime
    Get-ClusterVMs -Server CLUSTERNAME | Export-CSV -Path C:\Temp\ClusterVMs.csv -Append -Force -NoTypeInformation
    Get-ClusterVMs -File  #Choose an csv file.

    CSV File example:
    vmname01,clustername    # Search in all nodes
    vmname01,nodename01     # Faster
    vmname02,nodename02     # Faster
#>

#Requires -PSEdition Core -Modules ActiveDirectory,ImportExcel,Hyper-V
Import-Module ActiveDirectory,Hyper-V,ImportExcel

function Get-FileName ($spath) {
    $spath = $ReportsCsv
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $spath
    $OpenFileDialog.filter = "CSV (*.csv) | *.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.FileName
}
function Get-ClusterVMs {
    [CmdletBinding(DefaultParameterSetName = 'Server')]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Server')]
        [Alias('ComputerName', 'Host', 'Cluster', 'Hyper-V')]
        [string] $Server,

        [Parameter(Position = 1)]
        [Alias('CSV', 'FromCSV', 'FromFile', 'Import')]
        [switch] $File,

        [Parameter(Position = 1)]
        [Alias('VMName', 'Machine')]
        [string] $Name,

        [Parameter(Position = 2)]
        [Alias('Save', 'ExportTo')]
        [string] $Export
    )
    
    begin {
        $Result = @()
        $VMs = @()

        if (-Not ($PSBoundParameters.ContainsKey('File'))){
            try {
                Get-Cluster -Name $Server -ErrorAction Stop | Out-Null
                $ClusterNodes = (Get-ClusterNode -Cluster $Server).Name
            }
            Catch {
                Write-Host $_.Exception.Message -ForegroundColor Red
            }
        }

        if ($PSBoundParameters.ContainsKey('File')) {
            try {
                $FilePath = Import-Csv -Path (Get-FileName) -Header VMName,Server
                $VMsList = @()
                foreach ($x in $FilePath) {
                    $VMsList += Get-VM -ComputerName $x.Server -VMName $x.VMName -ErrorAction Stop  | Select-Object Name,@{Label = "Node"; Expression = "ComputerName"}
                }
                $VMsList = $VMsList | Sort-Object Name
            }
            catch {
                Write-Host $_.Exception.Message -ForegroundColor Red
                Break
            }
        }
        elseif ($PSBoundParameters.ContainsKey('Name')) {
            try {
                $VMsList = Get-VM -ComputerName $Server -VMName $Name -ErrorAction Stop | Select-Object Name,@{Label = "Node"; Expression = "ComputerName"}
            }
            catch {
                Write-Host $_.Exception.Message -ForegroundColor Red
                Break
            }
        }
        else {
            try {
                $SyncNodes = [System.Collections.Hashtable]::Synchronized(@{i = 1 })
                $VMsList = $ClusterNodes | ForEach-Object -Parallel {
                    $Node = $_
                    $Nodes = $USING:ClusterNodes
                    $Progress = $USING:SyncNodes
                    $Server = $USING:Server
                    $Count = $Progress.i
                    $Progress.i++

                    $WriteFirstProgress = @{
                        Activity            = "Working on $($Server)"
                        Status              = "$($Node)    |    $($Count) of $($Nodes.Count)"
                        CurrentOperation    = $Node
                        PercentComplete     = (($Count / $Nodes.Count) * 100)
                    }

                    Write-Progress @WriteFirstProgress

                    Get-VM -ComputerName $Node | ForEach-Object {
                        $List = $USING:VMs
                        $List += [PSCustomObject]@{
                            Name = $_.VMName
                            Node = $Node
                        }
                        return $List
                    }
                }
                $VMsList = $VMsList | Sort-Object Node, Name
            }
            catch {
                Write-Host $_.Exception.Message -ForegroundColor Red
                Break
            }
            Write-Progress -Activity "Working on $($Server)" -Status "Ready" -Completed
        }
    }
    
    process {
        $Sync = [System.Collections.Hashtable]::Synchronized(@{i = 1 })
        $VMsResult = $VMsList | ForEach-Object -Parallel {
            $VMName = $_.Name
            $Node = $_.Node
            $Items = $USING:VMsList
            $Progress = $USING:Sync
            $Count = $Progress.i
            $Progress.i++
            $Percent = ($Count / $Items.Count) * 100
            $Percent = "{0:N2}" -f ($Percent)

            $WriteSecondProgress = @{
                Activity            = "Working on $($Node)"
                Status              = "$($VMName)    |    $($Count) of $($Items.Count)    |    $($Percent)%"
                CurrentOperation    = $Node
                PercentComplete     = (($Count / $Items.Count) * 100)
            }

            Write-Progress @WriteSecondProgress

            try {
                $OS = (Get-ADComputer -Identity $VMName -Properties OperatingSystem).OperatingSystem
            }
            catch {
                $OS = "Not Windows or Not Domain Joined"
            }

            $GetVM = Get-VM -ComputerName $Node -VMName $VMName
            $GetVM | ForEach-Object {
                $IPAddresses    = ($($_.NetworkAdapters).IPAddresses | Where-Object {$_ -notmatch "::"} ) -join ';'
                $SwitchName     = $($_.NetworkAdapters).SwitchName -join ';'
            }

            Get-VMNetworkAdapterVlan -ComputerName $Node -VMName $VMName | ForEach-Object {
                $AccessVlanId   = $_.AccessVlanId -join ';'
                $OperationMode  = $_.OperationMode -join ';'
            }
            
            Get-VMNetworkAdapter -ComputerName $Node -VMName $VMName | ForEach-Object {
                $NetworkAdapter = $_.Name -join ';'
                $MacAddress     = ($_.MacAddress).Replace('..(?!$)', '$&:') -join ';'
            }

            Get-VHD -ComputerName $Node -VMId $GetVM.VMId | ForEach-Object {
                $VHDX = "{0:N2}" -f ($_.Size / 1024Mb) -join ';'
            }
            
            $ResultList = $USING:Result
            $ResultList += [PSCustomObject]@{
                Name                    = $GetVM.VMName
                State                   = $GetVM.State
                vCPUs                   = $GetVM.ProcessorCount
                CPUUsage                = $GetVM.CPUUsage
                RAM                     = "{0:N2}" -f ($GetVM.MemoryStartup / 1024Mb)
                MemoryAssigned          = "{0:N2}" -f ($GetVM.MemoryAssigned / 1024Mb)
                DiskSize                = $VHDX
                OperatingSystem         = $OS
                Uptime                  = $GetVM.Uptime
                IPAddresses             = $IPAddresses
                SwitchName              = $SwitchName
                AccessVlanId            = $AccessVlanId
                OperationMode           = $OperationMode
                NetworkAdapter          = $NetworkAdapter
                MacAddress              = $MacAddress
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
            Return $ResultList
        }
        Write-Progress -Activity "Working on $($Node)" -Status "Ready" -Completed
    }
    
    end {
        if ($PSBoundParameters.ContainsKey('Export')) {
            $VMsResult | Export-Excel $Export -WorksheetName $Server -Append -TitleBold -AutoSize -AutoFilter -FreezeTopRow -TableStyle Light8 -NoNumberConversion *
        }
        else {
            $VMsResult | Select-Object Name,State,vCPUs,CPUUsage,RAM,MemoryAssigned,Uptime,OperatingSystem | Format-Table
        }
    }
}