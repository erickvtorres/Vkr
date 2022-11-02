<#
.Description

Send Telegram Messages

.LINK

    .Linkedin:      https://www.linkedin.com/in/erickvtorres/
    .GitHub:        https://github.com/erickvtorres
    .TelegramBot:   https://core.telegram.org/bots

.NOTES

Just send a Telegram

    .Creator:       Erick Torres do Vale
    .Contact:       ericktorres@hotmail.com.br
    .Date:          2018
    .LastUpdate     02/11/2022
    .Version:       1.0

.EXAMPLE

    Send-Telegram -Message 'Hello Darkness'
    Send-Telegram -Message 'Hello Darkness' -Token <your Telegram Token> -ChatID <your Telegram Chat ID>
#>

function Send-Telegram {
    [CmdletBinding(DefaultParameterSetName = 'Message')]
    param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ParameterSetName = 'Message'
            )]
        [string]
        $Message,

        [Parameter(
            Mandatory = $false
            )]
        [string]
        $Token,

        [Parameter(
            Mandatory = $false
            )]
        [string]
        $ChatID
    )

    begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        if (-Not ($Token)){
            $Token = ""
        }
        
        if (-Not ($ChatID)){
            $ChatID = ""
        }
    }

    process {
        $Body = ConvertTo-Json -Compress @{
            chat_id = $ChatID
            text = $Message
            }

        $Params = @{
            Uri         = ("https://api.telegram.org/bot" + $Token + "/sendMessage")
            Method      = "Post"
            ContentType = "application/json;charset=utf-8"
            Body        = $Body
        }

        $Send = Invoke-RestMethod @Params

        if ($Send.ok -ne 'True'){
            Write-Host $Send.result -ForegroundColor Red
            Break
        }
    }
    
    end {
        $Send    = $Null
        $Message = $Null
    }
}
