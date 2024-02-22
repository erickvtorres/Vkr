function Send-TeamsChat {
<#
.SYNOPSIS
    Send teams chat using New-MgChatMessage from Microsoft.Graph Module.

.DESCRIPTION
    Send teams chat sir.
    Do not hard code your credentials, get from Azure Key Vault, it's almost free.
    Add these scopes to you application: 'Chat.Create','Chat.ReadWrite','User.Read','User.Read.All'

.LINK
    .Linkedin:      https://www.linkedin.com/in/erickvtorres/
    .GitHub:        https://github.com/erickvtorres

.NOTES
    .Creator:       Erick Torres do Vale
    .Contact:       ericktorres@hotmail.com.br
    .Date:          2022-11-08
    .LastUpdate:    2024-02-21
    .Version:       1.0.2

.PARAMETER Identity
    Accetps userPrincipalName or MgUserID

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
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Identity,

        [Parameter(Position = 1, Mandatory = $true)]
        [string]$Message,

        [Parameter(Position = 2, Mandatory = $false)]
        [ValidateSet('Normal','High','Urgent')]
        [string]$Importance = 'Normal'
    )
    
    begin {
        if (Get-MgContext){
            Disconnect-MgGraph
        }
        $Body =  @{
            Grant_Type    = 'password'
            Scope         = 'https://graph.microsoft.com/.default'
            Client_Id     = '<your client id>'
            Client_Secret = '<your client secret | do not hardcode>'
            username      = '<your account username'
            password      = '<your account password | do not hardcode'
        }

        $Rest = @{
            Uri    = "https://login.microsoftonline.com/4614929d-91d7-4e1f-9846-8b09a7c22860/oauth2/v2.0/token"
            Method = 'Post'
            Body   = $Body
        }
        
        $Connect = Invoke-RestMethod @Rest
        $Token   = $Connect.access_token

        try {
            Connect-MgGraph -AccessToken ($Token | ConvertTo-SecureString -AsPlainText -Force) -NoWelcome
        }
        catch {
            Write-Error -Message $_.Exception.Message
            Break
        }
    }
    
    process {
        try{
            $TeamsUser = Get-MgUser -UserId $Identity -ErrorAction Stop
            $ChatParam = @{
                ChatType = 'oneOnOne'
                Members  = @(
                    @{
                        '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                        roles             = @('owner')
                        'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('" + (Get-MgUser -UserId (Get-MgContext).account).id + "')"
                    }
                    @{
                        '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
                        roles             = @('owner')
                        'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('" + $TeamsUser.id + "')"
                    }
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
