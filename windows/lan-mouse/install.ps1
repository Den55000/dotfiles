# Install Lan Mouse with a tray helper and a Start menu shortcut.
#   .\install.ps1                  latest release from GitHub
#   .\install.ps1 -Version v0.11.0 a specific release
# Lan Mouse goes to %LOCALAPPDATA%\Programs\lan-mouse. The tray helper
# (lan-mouse-tray.cs) keeps `lan-mouse daemon` running when the window is
# closed; the "Lan Mouse" shortcut starts the helper, which opens the window.
# The release shortcut is set to Ctrl+Alt+Down in config.toml; release.ahk
# (needs AutoHotkey v2, run by the helper) keeps Ctrl+Shift+Win+Alt working too.
# Re-running updates Lan Mouse and rebuilds the helper. The rest of
# %LOCALAPPDATA%\lan-mouse (the pairing in config.toml, lan-mouse.pem) is per
# machine and isn't touched.
param([string]$Version = 'latest')
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$dest = Join-Path $env:LOCALAPPDATA 'Programs\lan-mouse'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$shortcut = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Lan Mouse.lnk'

# A running copy locks its files
Get-Process lan-mouse-tray, lan-mouse -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

$api = 'https://api.github.com/repos/feschber/lan-mouse/releases'
$release = if ($Version -eq 'latest') { Invoke-RestMethod "$api/latest" } else { Invoke-RestMethod "$api/tags/$Version" }
$asset = $release.assets | Where-Object name -eq 'lan-mouse-windows-x86_64.zip'
if (-not $asset) { throw "release $($release.tag_name) has no lan-mouse-windows-x86_64.zip" }

$tmp = Join-Path ([IO.Path]::GetTempPath()) "lan-mouse-$($release.tag_name)"
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $tmp | Out-Null
Write-Host "downloading  Lan Mouse $($release.tag_name)" -ForegroundColor Cyan
Invoke-WebRequest $asset.browser_download_url -OutFile "$tmp\lan-mouse.zip"
Expand-Archive "$tmp\lan-mouse.zip" "$tmp\files"

New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item "$tmp\files\*" $dest -Recurse -Force
Copy-Item "$here\lan-mouse.ico", "$here\release.ahk" $dest -Force
Remove-Item $tmp -Recurse -Force

# Top-level keys have to come before the [[clients]] tables
$config = Join-Path $env:LOCALAPPDATA 'lan-mouse\config.toml'
$lines = @()
if (Test-Path $config) { $lines = @(Get-Content $config | Where-Object { $_ -notmatch '^\s*release_bind\s*=' }) }
New-Item -ItemType Directory -Force (Split-Path $config) | Out-Null
[IO.File]::WriteAllLines($config, [string[]](@('release_bind = ["KeyLeftCtrl", "KeyLeftAlt", "KeyDown"]') + $lines))
Write-Host "release key  Ctrl+Alt+Down (and Ctrl+Shift+Win+Alt via release.ahk)" -ForegroundColor Cyan

Write-Host "building     lan-mouse-tray.exe" -ForegroundColor Cyan
& $csc /nologo /target:winexe "/win32icon:$here\lan-mouse.ico" /r:System.Management.dll `
    "/out:$dest\lan-mouse-tray.exe" "$here\lan-mouse-tray.cs"
if ($LASTEXITCODE -ne 0) { throw 'compiling lan-mouse-tray.cs failed' }

$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($shortcut)
$lnk.TargetPath = "$dest\lan-mouse-tray.exe"
$lnk.WorkingDirectory = $dest
$lnk.IconLocation = "$dest\lan-mouse.ico,0"
$lnk.Description = 'Lan Mouse - share mouse and keyboard across computers'
$lnk.Save()
Write-Host "installed    $dest" -ForegroundColor Cyan
Write-Host "shortcut     $shortcut" -ForegroundColor Cyan
