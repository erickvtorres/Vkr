<#
.Description
    Easy way to generate password

.LINK
    .Linkedin:      https://www.linkedin.com/in/erickvtorres/
    .GitHub:        https://github.com/erickvtorres

.NOTES

    .Creator:       Erick Torres do Vale
    .Contact:       ericktorres@hotmail.com.br
    .Date:          04/07/2023
    .LastUpdate     04/07/2023
    .Version:       0.0.1

.EXAMPLE
    New-Password
    New-Password -Size 200 -Complexity High
    New-Password -Size 200 -Complexity High -AsSecureString
#>
function New-Password {
    param (
        [Parameter(Mandatory = $false)]
        [int16]$Size = 10,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Low','Medium','High')]
        [string]$Complexity = 'medium',

        [Parameter(Mandatory = $false)]
        [switch]$AsSecureString
    )
    $letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    $numbers = '0123456789'
    $special = '!@#$%^&*()><_-+=:'
    switch ($Complexity){
        low    {$characters = $letters}
        medium {$characters = $letters + $numbers}
        high   {$characters = $letters + $numbers + $special}
        default {}
    }
    $Password = ($characters.ToCharArray() | Sort-Object { Get-Random })[0..$Size] -join ''
    if ($AsSecureString){
        $Password = $Password | ConvertTo-SecureString -AsPlainText -Force
    }
    Return $Password
}
