<#
.SYNOPSIS
    Send teams group chat using New-MgChatMessage from Microsoft.Graph Module.

.DESCRIPTION
    Send teams group chat sir.
    Do not hard code your credentials, get from Azure Key Vault, it's almost free.
    Add these scopes to you application: 'Chat.Create','Chat.ReadWrite','User.Read','User.Read.All'

.LINK
    .Linkedin:      https://www.linkedin.com/in/erickvtorres/
    .GitHub:        https://github.com/erickvtorres

.NOTES
    .Creator:       Erick Torres do Vale
    .Contact:       ericktorres@hotmail.com.br
    .Date:          2023-03-29
    .LastUpdate:    2023-03-29
    .Version:       1.0.0

.PARAMETER Identities
    Accetps userPrincipalName or MgUserID

.PARAMETER Topic
    Group chat name

.PARAMETER Message
    Accept HTML.
    Text you desire!

.PARAMETER Importance
    Normal
        Chat like any other
    Important
        Send user an alert
    Urgent
        Send user an alert each 2 minutes until they read the message
    
.EXAMPLE
    Send-TeamsChat -Identity erick@vkrinc.onmicrosoft.com -Message 'Hello' -Importance Urgent    
#>
#Requires -Modules Microsoft.Graph.Teams

function Send-TeamsGroupChat {
    [CmdletBinding()]
    param (
        [Parameter(
            Position  = 0,
            Mandatory = $true
        )]
        [array]
        $Identities,

        [Parameter(
            Position  = 1,
            Mandatory = $true
        )]
        [string]
        $Topic,

        [Parameter(
            Position  = 2,
            Mandatory = $true
        )]
        [string]
        $Message,

        [Parameter(
            Position  = 3,
            Mandatory = $false
        )]
        [ValidateSet(
            'Normal','High','Urgent'
        )]
        [string]
        $Importance
    )
    
    begin {
        . 'C:\Unimed\pwsh\PRD\Get-Secret.ps1'

        if (-Not $Importance){
            $Importance = 'Normal'
        }

        if (-Not (Get-MgContext)){
            $Body =  @{
                Grant_Type    = 'password'
                Scope         = 'https://graph.microsoft.com/.default'
                Client_Id     = '<your client id>'
                Client_Secret = '<your client secret | do not hardcode>'
                username      = '<your account username'
                password      = '<your account password | do not hardcode'
            }
    
            $Rest = @{
                Uri    = "https://login.microsoftonline.com/<your tenant id>/oauth2/v2.0/token"
                Method = 'Post'
                Body   = $Body
            }
            
            $Connect = Invoke-RestMethod @Rest
            $Token   = $Connect.access_token

            try {
                Connect-MgGraph -AccessToken $Token
            }
            catch {
                Write-Error -Message $_.Exception.Message
                Break
            }
        }
    }
    
    process {
        $Members = New-Object -TypeName System.Collections.ArrayList
        try{
            $Identities | ForEach-Object {
                $TeamsUser = Get-MgUser -UserId $_ -ErrorAction Stop
                $TeamsUser
                $Members.Add(
                    @{
                        '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                        Roles             = @('owner')
                        'User@odata.bind' = "https://graph.microsoft.com/v1.0/users('" + $TeamsUser.id + "')"
                    }
                )
            }
            
            $ChatParam = @{
                ChatType = 'group'
                Topic    = $Topic
                Members  = @(
                    @{
                        '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                        Roles             = @('owner')
                        'User@odata.bind' = "https://graph.microsoft.com/v1.0/users('" + (Get-MgUser -UserId (Get-MgContext).account).id + "')"
                    }
                    $Members
                )
            }

            $ChatSession = New-MgChat -BodyParameter $ChatParam

            $Body = @{
                ContentType = 'html'
                Content     = $Message
            }

            New-MgChatMessage -ChatId $ChatSession.ID -Body $Body -Importance $Importance
            Write-Output "Teams chat message sent to $($TeamsUser.DisplayName)"
        }
        catch {
            Write-Warning -Message $_.Exception.Message
        }
    }
    
    end {
        Disconnect-MgGraph
        $Token = $null
    }
}
