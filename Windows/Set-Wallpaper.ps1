<#
.SYNOPSIS
	Updte wallpaper

.DESCRIPTION
  Get principal screen resolution to copy image from new wallapper to destionation folder C:\Wallpaper
	Force update the Wallpaper

 .LINK
    .Linkedin:      https://www.linkedin.com/in/erickvtorres/
    .GitHub:        https://github.com/erickvtorres

.NOTES
    .Creator:       Erick Torres do Vale
    .Contact:       ericktorres@hotmail.com.br
    .Date:          2022-10-07
    .LastUpdate:    2023-12-13
    .Version:       1.0.1
#>

$Screen = @()
$WallpaperFolder      = "\\domain.local\NETLOGON\Image\wallpaper"
$Exist                = Test-Path -Path C:\Wallpaper\Background.jpg

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Screen]::AllScreens |
ForEach-Object {
	$Screen += [pscustomobject]@{
		DeviceName   = $_.DeviceName.Replace('\\.\', '')
		Height       = $_.bounds.Height
		Width        = $_.bounds.Width
		BitsPerPixel = $_.BitsPerPixel
		Primary      = $_.Primary
	}
}

$DisplayResolution = $Screen | Where-Object { $_.Primary -eq $true }
$DisplayResolution = [string]$DisplayResolution.Width + 'x' + [string]$DisplayResolution.Height

Write-Host "$([char]0x203A) Display resolution: " -NoNewline
Write-Host $($DisplayResolution) -ForegroundColor Green

$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ": Display resolution " + $DisplayResolution | Out-File -LiteralPath C:\Wallpaper\Wallpaper.log -Append -Encoding utf8

switch ($DisplayResolution) {
	'1280x720'  { $Resolution = '1280x720_.jpg' }
	'1280x1024' { $Resolution = '1280x1024_.jpg' }
	'1366x768'  { $Resolution = '1366x768_.jpg' }
	'1440x900'  { $Resolution = '1440x900_.jpg' }
	'1920x1080' { $Resolution = '1920x1080_.jpg' }
	'2560x1080' { $Resolution = '2560x1080_.jpg' }
	Default { $Resolution = '1366x768_.jpg' }
}

if (-Not (Test-Path 'C:\Wallpaper')){
	Write-Host "$([char]0x203A) Wallpaper folder not found" -ForegroundColor Red
	Break
}

Write-Host "$([char]0x203A) Wallpaper exist: " -NoNewline
if ($Exist -eq $true) {

	$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ": Wallpaper exist equal True" | Out-File -LiteralPath C:\Wallpaper\Wallpaper.log -Append -Encoding utf8

	Write-Host $Exist -ForegroundColor Green
	Write-Host "$([char]0x203A) Wallpaper updated: " -NoNewline

	$LocalBackground = (Get-FileHash -Path C:\Wallpaper\Background.jpg).Hash
	$ServerBackground = (Get-FileHash -Path $WallpaperFolder\$Resolution).Hash
	if ($LocalBackground -ne $ServerBackground) {
		Write-Host "False" -ForegroundColor Red
		try {
			Copy-Item -Path $WallpaperFolder\$Resolution -Destination C:\Wallpaper\Background.jpg -Force
			$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ": Wallpaper file updated from netlogon" | Out-File -LiteralPath C:\Wallpaper\Wallpaper.log -Append -Encoding utf8	
		}
		catch {
			$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ": Wallpaper file not updated - " + $($_.Exception.Message) | Out-File -LiteralPath C:\Wallpaper\Wallpaper.log -Append -Encoding utf8
			Break
		}
	}
 else {
		Write-Host "True" -ForegroundColor Green
		$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ": Wallpaper file is updated" | Out-File -LiteralPath C:\Wallpaper\Wallpaper.log -Append -Encoding utf8
	}
}
else {
	Write-Host $Exist -ForegroundColor Red
	Write-Host "$([char]0x203A) Wallpaper transfered: " -NoNewline
	$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ": Wallpaper exist equal False" | Out-File -LiteralPath C:\Wallpaper\Wallpaper.log -Append -Encoding utf8
	try {
		Copy-Item -Path $WallpaperFolder\$Resolution -Destination C:\Wallpaper\Background.jpg -Force
		$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ": Wallpaper file transfered" | Out-File -LiteralPath C:\Wallpaper\Wallpaper.log -Append -Encoding utf8
		Write-Host "True" -ForegroundColor Green
	}
	catch {
		$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ": Wallpaper file not transfered - " + $($_.Exception.Message) | Out-File -LiteralPath C:\Wallpaper\Wallpaper.log -Append -Encoding utf8
		Write-Host "False" -ForegroundColor Red
	}
}

$NotUsed = Get-ChildItem -Path C:\Wallpaper -Recurse | Where-Object { $_.Name -ne 'Background.jpg' -and $_.Name -ne 'Wallpaper.log' } | Select-Object FullName
$NotUsed | ForEach-Object { Remove-Item -Path $_.FullName -Force }

#Force wallpaper update
Start-Process -FilePath "C:\Windows\System32\cmd.exe" -ArgumentList {/c RUNDLL32.EXE USER32.DLL, UpdatePerUserSystemParameters 1, True}
$imgPath="C:\Wallpaper\Background.jpg"
$code = @' 
using System.Runtime.InteropServices; 
namespace Win32{ 
    
     public class Wallpaper{ 
        [DllImport("user32.dll", CharSet=CharSet.Auto)] 
         static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ; 
         
         public static void SetWallpaper(string thePath){ 
            SystemParametersInfo(20,0,thePath,3); 
         }
    }
 } 
'@
Add-Type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)
