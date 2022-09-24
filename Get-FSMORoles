<#
    .SYNOPSIS
    Display where AD FSMOs is installed

    .LINK
    https://github.com/erickvtorres/Vkr

    .MICROSOFT DOCS
    https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/fsmo-roles

#>

function Get-FSMORoles {
    $ADForest = Get-ADADForest
    $ADDomain = Get-ADADDomain

    $FSMO = [PSCustomObject] @{
        'Schema Master'          = $ADForest.SchemaMaster
        'ADDomain Naming Master' = $ADForest.ADDomainNamingMaster
        'RID Master'             = $ADDomain.RIDMaster
        'PDC Emulator'           = $ADDomain.PDCEmulator
        'Infrastructure Master'  = $ADDomain.InfrastructureMaster
    }
    Return $FSMO
}
