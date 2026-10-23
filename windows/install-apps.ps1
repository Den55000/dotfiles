# Reinstall my Windows apps with winget.
#   .\install-apps.ps1           install everything that isn't installed yet
#   .\install-apps.ps1 -DryRun   only show what would be installed
# Apps winget can't install are listed at the end with where to get them.
param([switch]$DryRun)

$apps = @(
    # Browsers
    @{ Id = 'LibreWolf.LibreWolf' }
    @{ Id = 'Brave.Brave' }
    @{ Id = 'TorProject.TorBrowser' }

    # Sync, passwords, VPN
    @{ Id = 'Nextcloud.NextcloudDesktop' }
    @{ Id = 'KeePassXCTeam.KeePassXC' }
    @{ Id = 'ente-io.auth-desktop' }
    @{ Id = 'Cloudflare.Warp' }

    # Office, notes, chat
    @{ Id = 'Mozilla.Thunderbird' }
    @{ Id = 'Obsidian.Obsidian' }
    @{ Id = 'Discord.Discord' }
    @{ Id = 'Telegram.TelegramDesktop' }
    @{ Id = 'AppByTroye.KoodoReader' }
    @{ Id = 'JGraph.Draw' }
    @{ Id = 'Anthropic.Claude' }

    # Dev tools
    @{ Id = 'Git.Git' }
    @{ Id = 'GitHub.cli' }
    @{ Id = 'Microsoft.VisualStudioCode' }
    @{ Id = 'Neovim.Neovim' }
    @{ Id = 'Microsoft.WindowsTerminal' }
    @{ Id = 'Microsoft.WSL' }
    @{ Id = 'Docker.DockerDesktop' }
    @{ Id = 'DBeaver.DBeaver.Community' }
    @{ Id = 'Heroku.HerokuCLI' }

    # Languages
    @{ Id = 'Python.Python.3.13' }
    @{ Id = 'OpenJS.NodeJS.22' }
    @{ Id = 'Oracle.JDK.21' }
    @{ Id = 'Oracle.JDK.25' }

    # Printer
    @{ Id = '9WZDNCRFHWLH'; Source = 'msstore' }   # HP Smart

    # Science and writing
    @{ Id = 'OSGeo.QGIS_LTR' }
    @{ Id = 'MiKTeX.MiKTeX' }
    @{ Id = 'TeXstudio.TeXstudio' }
    @{ Id = 'JohnMacFarlane.Pandoc' }
    @{ Id = 'OliverBetz.ExifTool' }
    @{ Id = 'Gyan.FFmpeg' }

    # Media and creative
    @{ Id = 'BlenderFoundation.Blender' }
    @{ Id = 'GIMP.GIMP.3' }
    @{ Id = 'dotPDN.PaintDotNet' }
    @{ Id = 'Meltytech.Shotcut' }
    @{ Id = 'OBSProject.OBSStudio' }
    @{ Id = 'VideoLAN.VLC' }
    @{ Id = 'FreeTube.FreeTube' }
    @{ Id = 'DuongDieuPhap.ImageGlass' }

    # Utilities
    @{ Id = 'Microsoft.PowerToys' }
    @{ Id = 'AutoHotkey.AutoHotkey' }
    @{ Id = '7zip.7zip' }
    @{ Id = 'AntibodySoftware.WizTree' }
    @{ Id = 'Devolutions.UniGetUI' }
    @{ Id = 'qBittorrent.qBittorrent' }
    @{ Id = '9N621DM2LVHQ'; Source = 'msstore' }   # OP Auto Clicker - Auto Tap

    # Games
    @{ Id = 'Valve.Steam' }
    @{ Id = 'SuperTuxKart.SuperTuxKart' }
)

$manual = @(
    'Microsoft 365            Word/Excel/PowerPoint only: winget install Microsoft.OfficeDeploymentTool, then as admin'
    '                         setup.exe /configure office-config.xml (in this folder); sign in with the business account'
    'Lan Mouse                lan-mouse\install.ps1 (in this folder): release zip + tray helper + Start menu shortcut'
    'Tresorit                 https://tresorit.com/download'
    'GlobalProtect            from the work VPN portal (the version it hands out matches the gateway)'
    'DaVinci Resolve          https://www.blackmagicdesign.com/products/davinciresolve'
    'Cheat Engine             https://www.cheatengine.org (decline the bundled offers in the installer)'
    'Keyboard Layout Creator  https://www.microsoft.com/download/details.aspx?id=102134'
    'Steam games              reinstall from the Steam library'
)

$failed = @()
foreach ($app in $apps) {
    $source = if ($app.Source) { $app.Source } else { 'winget' }
    winget list --id $app.Id --exact --source $source --accept-source-agreements --disable-interactivity *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "already installed  $($app.Id)" -ForegroundColor DarkGray
        continue
    }
    if ($DryRun) {
        Write-Host "would install      $($app.Id)" -ForegroundColor Cyan
        continue
    }
    Write-Host "installing         $($app.Id)" -ForegroundColor Cyan
    winget install --id $app.Id --exact --source $source --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { $failed += $app.Id }
}

if ($failed) {
    Write-Host "`nFailed:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  $_" }
}
Write-Host "`nInstall by hand:" -ForegroundColor Yellow
$manual | ForEach-Object { Write-Host "  $_" }
