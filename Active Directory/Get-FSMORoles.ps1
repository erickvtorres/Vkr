<#
.SYNOPSIS
    Display where AD FSMOs is installed
.DESCRIPTION
    Get info from AD Forest and AD Domain and show only the FSMO Roles.
.LINK
    Linkedin        : https://www.linkedin.com/in/erickvtorres
    GitHub          : https://github.com/erickvtorres
    Docs            : https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/fsmo-roles
.NOTES
    Creator         : Erick Torres do Vale
    Contact         : ericktorres@hotmail.com.br
    Date            : 2022-11-02
    LastUpdate      : 2022-11-02
    Version         : 0.2   
#>

#Requires -Modules ActiveDirectory
function Get-FSMORoles {
    $ADForest = Get-ADForest
    $ADDomain = Get-ADDomain

    $FSMO = [PSCustomObject] @{
        'Schema Master'          = $ADForest.SchemaMaster
        'ADDomain Naming Master' = $ADForest.DomainNamingMaster
        'RID Master'             = $ADDomain.RIDMaster
        'PDC Emulator'           = $ADDomain.PDCEmulator
        'Infrastructure Master'  = $ADDomain.InfrastructureMaster
    }
    Return $FSMO
}
