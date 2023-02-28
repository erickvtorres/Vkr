oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\vkr.omp.json" | Invoke-Expression
Set-PSReadLineOption -PredictionSource History
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
$PSDefaultParameterValues = @{ '*:Encoding' = 'utf8' }
function NoHistory {
    $hist = (Get-PSReadLineOption).HistorySavePath
    Set-Content -Value "" -Path $hist    
}

Clear-Host
