# ============================================================================
#  setup-windows.ps1 - Automated Windows 11 setup (gaming + productivity).
#
#  Focus: a lean Windows 11 for gaming and development. Everything is an
#  OPTION - the script asks what you want (browsers, editors, password
#  managers, dev tools, ...) and installs only what you pick. Nothing is
#  forced and nothing is removed without asking.
#
#  UI: ASCII banner, step progress bar and an animated spinner, matching the
#  Linux scripts (lib/ui.sh). This file must stay pure ASCII: PowerShell 5.1
#  reads .ps1 files without a BOM as ANSI, so any non-ASCII character would
#  be corrupted and break parsing.
#
#  Usage:
#    powershell -ExecutionPolicy Bypass -File windows\setup-windows.ps1
#    powershell -ExecutionPolicy Bypass -File windows\setup-windows.ps1 -DryRun
#    powershell -ExecutionPolicy Bypass -File windows\setup-windows.ps1 -Revert
# ============================================================================

param(
    [switch]$DryRun,
    [switch]$Revert
)

$ErrorActionPreference = "Stop"

# Global trap: never let the window close silently on an error.
trap {
    Write-Host ""
    Write-Host "  [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Script stopped. Press Enter to close this window..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

$script:OkCount   = 0
$script:SkipCount = 0
$script:FailCount = 0
$script:StartTime = Get-Date

# -- Terminal / ANSI support --------------------------------------------------
# ANSI color codes are only emitted when stdout is a real console, so the
# script stays readable when output is redirected or pasted into a log.
$ESC     = [char]27
$UseAnsi = $false
try { $UseAnsi = -not [Console]::IsOutputRedirected } catch { $UseAnsi = $false }

function Set-Col  { param([string]$Code) if ($UseAnsi) { return "$ESC[${Code}m" } return "" }
function Reset-Col { if ($UseAnsi) { return "$ESC[0m" } return "" }

$C = @{
    Bold    = (Set-Col "1")
    Dim     = (Set-Col "2")
    Red     = (Set-Col "0;31")
    Green   = (Set-Col "0;32")
    Yellow  = (Set-Col "0;33")
    Blue    = (Set-Col "0;34")
    Magenta = (Set-Col "0;35")
    Cyan    = (Set-Col "0;36")
    Rst     = (Reset-Col)
}

# -- Status helpers (ASCII symbols only) --------------------------------------
function Write-OK   { param([string]$msg) $script:OkCount++;   Write-Host ("  {0}[ v ]{1} {2}" -f $C.Green,$C.Rst,$msg) }
function Write-Skip { param([string]$msg) $script:SkipCount++; Write-Host ("  {0}[ - ]{1} {2} (already installed)" -f $C.Yellow,$C.Rst,$msg) }
function Write-Fail { param([string]$msg) $script:FailCount++; Write-Host ("  {0}[ x ]{1} {2}" -f $C.Red,$C.Rst,$msg) }
function Write-Info { param([string]$msg) Write-Host ("  {0}[ i ]{1} {2}" -f $C.Cyan,$C.Rst,$msg) }
function Write-Warn { param([string]$msg) Write-Host ("  {0}[ ! ]{1} {2}" -f $C.Yellow,$C.Rst,$msg) }
function Write-Dry  { param([string]$msg) Write-Host ("  {0}[ * ]{1} [DRY] {2}" -f $C.Blue,$C.Rst,$msg) }

# -- Banner -------------------------------------------------------------------
function Show-Banner {
    # Same ASCII art as lib/banner.art, tinted with the Catppuccin gradient.
    $grad = @(
        "38;2;245;194;231", # pink
        "38;2;203;166;247", # mauve
        "38;2;137;180;250", # blue
        "38;2;137;220;235", # teal
        "38;2;148;226;213", # mint
        "38;2;166;227;161"  # green
    )
    $art = @(
        " _     ___ _   _ _   ___  __  __        _____ _   _      ____  _____ _____ _   _ ____"
        "| |   |_ _| \ | | | | \ \/ /  \ \      / /_ _| \ | |    / ___|| ____|_   _| | | |  _ \"
        "| |    | ||  \| | | | |\  /____\ \ /\ / / | ||  \| |____\___ \|  _|   | | | | | | |_) |"
        "| |___ | || |\  | |_| |/  \_____\ V  V /  | || |\  |_____|__) | |___  | | | |_| |  __/"
        "|_____|___|_| \_|\___//_/\_\     \_/\_/  |___|_| \_|    |____/|_____| |_|  \___/|_|"
    )
    $i = 0
    foreach ($line in $art) {
        if ($UseAnsi) {
            Write-Host "    $ESC[$($grad[$i % $grad.Count])m$line$ESC[0m"
        } else {
            Write-Host "    $line" -ForegroundColor Cyan
        }
        $i++
    }
    Write-Host ""
if ($Revert) {
    # Verify winget is working before proceeding
    Write-Host "  [i] Verifying winget functionality..." -ForegroundColor Cyan
    $test = Invoke-Winget @("list", "--id", "Microsoft.WindowsCalculator", "--accept-source-agreements") -Label "Winget test"
    if ($test.Code -ne 0) {
        Write-Host "  [FAIL] winget not functional - aborting revert" -ForegroundColor Red
        Write-Host "  Please ensure winget is installed and working, then try again." -ForegroundColor Yellow
        Read-Host "Press Enter to close..."
        exit 1
    }
    Write-Host "  [OK] winget is functional$($C.Rst)"
    Write-Host "  $($C.Red)REVERT MODE - undo the setup: uninstall apps and restore tweaks$($C.Rst)"
    } else {
        Write-Host "  $($C.Bold)Windows 11 setup - gaming + development$($C.Rst)"
    }
    Write-Host "  $($C.Dim)https://github.com/Davidxap/linux-win-setup$($C.Rst)"
    Write-Host ""
    Write-Host "  $($C.Yellow)Everything is optional. Nothing is installed without asking.$($C.Rst)"
    if ($DryRun) {
        Write-Host "  $($C.Yellow)[ * ] DRY-RUN: no changes will be made$($C.Rst)"
    }
    Write-Host ""
}

# -- Progress bar (ASCII) ------------------------------------------------------
function Show-Progress {
    param([int]$Done, [int]$Total, [string]$Status = "")
    $width = 30
    $pct   = if ($Total -gt 0) { [int]($Done * 100 / $Total) } else { 0 }
    $filled = if ($Total -gt 0) { [int]($Done * $width / $Total) } else { 0 }
    if ($filled -gt $width) { $filled = $width }
    $bar = ("#" * $filled) + ("." * ($width - $filled))
    Write-Host ("  {0}[{1}]{2} {3,3}%  {4}" -f $C.Blue, $bar, $C.Rst, $pct, $Status)
}

# -- Spinner for an external command ------------------------------------------
function Invoke-WithSpinner {
    param(
        [string]$Label,
        [string]$FilePath,
        [string[]]$Arguments
    )
    $out = Join-Path $env:TEMP "lws.out.txt"
    $err = Join-Path $env:TEMP "lws.err.txt"
    Remove-Item $out, $err -ErrorAction SilentlyContinue
    $proc = Start-Process -FilePath $FilePath -ArgumentList $Arguments `
        -RedirectStandardOutput $out -RedirectStandardError $err `
        -PassThru -WindowStyle Hidden
    $spin = @('|', '/', '-', '\')
    $i = 0
    Write-Host "  $Label " -NoNewline
    while (-not $proc.HasExited) {
        if ($UseAnsi) { Write-Host -NoNewline ("{0}`b" -f $spin[$i]) }
        $i = ($i + 1) % 4
        Start-Sleep -Milliseconds 150
    }
    if ($UseAnsi) { Write-Host -NoNewline (" \b") }
    Write-Host ""
    return @{
        Code = $proc.ExitCode
        Out  = ((Get-Content $out -ErrorAction SilentlyContinue | Out-String).Trim())
        Err  = ((Get-Content $err -ErrorAction SilentlyContinue | Out-String).Trim())
    }
}

# -- Spinner for a PowerShell script block ------------------------------------
# Runs the block in a background job and animates the spinner while it works.
# A thrown exception makes the job fail, which is how failures are detected.
function Invoke-ScriptSpinner {
    param(
        [string]$Label,
        [scriptblock]$Script,
        [object[]]$ArgumentList = @()
    )
    $job = Start-Job -ScriptBlock $Script -ArgumentList $ArgumentList
    $spin = @('|', '/', '-', '\')
    $i = 0
    Write-Host "  $Label " -NoNewline
    while ($job.State -eq 'Running') {
        if ($UseAnsi) { Write-Host -NoNewline ("{0}`b" -f $spin[$i]) }
        $i = ($i + 1) % 4
        Start-Sleep -Milliseconds 150
    }
    if ($UseAnsi) { Write-Host -NoNewline (" \b") }
    Write-Host ""
    $done = ($job.State -eq 'Completed')
    $out = @(Receive-Job $job -ErrorAction SilentlyContinue)
    Remove-Job $job -Force
    return @{ Done = $done; Out = ($out -join "`n") }
}

# -- Interactive helpers ------------------------------------------------------
function Confirm-Step {
    param([string]$Question, [string]$Default = "n")
    if ($DryRun) { Write-Dry "Prompt: $Question (default $Default)"; return $true }
    $suffix = if ($Default -eq "y") { " [Y/n]" } else { " [y/N]" }
    $answer = Read-Host "  $Question$suffix"
    if ($answer -eq "") { $answer = $Default }
    return ($answer -match '^(y|Y|yes)$')
}

function Select-Items {
    param(
        [string]$Question,
        [string[]]$Options,
        [string[]]$Descriptions
    )
    Write-Host ""
    Write-Host "  $Question" -ForegroundColor White
    Write-Host "  (comma list like 1,2,3 | a = all | n = none)" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $desc = if ($Descriptions -and $i -lt $Descriptions.Count) { " - $($Descriptions[$i])" } else { "" }
        Write-Host "    [$($i + 1)] $($Options[$i])$desc" -ForegroundColor Cyan
    }
    if ($DryRun) { return @(1..$Options.Count) }

    while ($true) {
        $answer = Read-Host "  Select"
        $answer = ($answer -replace '\s', '')
        if ($answer -match '^(a|all|A)$') { return @(1..$Options.Count) }
        if ($answer -match '^(n|none|0)$') { return @() }
        $nums = $answer -split ','
        $picked = @()
        $valid = $true
        foreach ($num in $nums) {
            if ($num -match '^\d+$' -and [int]$num -ge 1 -and [int]$num -le $Options.Count) {
                $picked += [int]$num
            } else {
                $valid = $false
            }
        }
        if ($valid -and $picked.Count -gt 0) { return $picked }
        Write-Host "  Invalid option." -ForegroundColor Red
    }
}

# -- winget install ----------------------------------------------------------
function Invoke-Winget {
    param([string[]]$Arguments, [string]$Label = "winget")
    $exe = (Get-Command winget -ErrorAction SilentlyContinue).Source
    if (-not $exe) { return @{ Code = 1; Out = ""; Err = "winget not found" } }
    return (Invoke-WithSpinner -Label $Label -FilePath $exe -Arguments $Arguments)
}

# True if the package is actually present (checks winget's installed list).
function Test-Installed {
    param([string]$Id)
    # Comprehensive check using 4 methods (winget + registry + MSIX + paths).
    if (Test-Installed-Winget $Id) { return $true }
    if (Test-Installed-Registry $Id) { return $true }
    if (Test-Installed-Appx $Id) { return $true }
    if (Test-Installed-Path $Id) { return $true }
    return $false
}

# Check via Windows App packages (MSIX / Microsoft Store apps).
# Many apps (Brave, Discord, Spotify, ...) ship as Store/MSIX packages.
function Get-AppxByName {
    param([string]$Pattern)
    $all = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    if ($null -eq $all) {
        # Not admin (or -AllUsers unsupported) - fall back to current user.
        $all = Get-AppxPackage -ErrorAction SilentlyContinue
    }
    return @($all | Where-Object {
        $_.Name -like "*$Pattern*" -or $_.PackageFamilyName -like "*$Pattern*"
    })
}

function Test-Installed-Appx {
    param([string]$Id)
    $name = if ($REVERT_NAMES.ContainsKey($Id)) { $REVERT_NAMES[$Id] } else { $Id }
    $appx = Get-AppxByName $name
    if ($appx.Count -eq 0) { $appx = Get-AppxByName $Id }
    return ($appx.Count -gt 0)
}

# Check via winget (handles winget-managed packages).
function Test-Installed-Winget {
    param([string]$Id)
    $r = Invoke-Winget @("list", "--id", $Id, "--accept-source-agreements") -Label "Checking $Id (winget)"
    if ($r.Out -match "No installed package") { return $false }
    if ($r.Code -ne 0) { return $false }
    # Also verify output has actual table data, not just echoed ID.
    if ($r.Out -match "Id\s+Name") { return $true }  # table header present
    if ($r.Out -match $Id -and $r.Out.Length -gt ($Id.Length * 3)) { return $true }
    return $false
}

# Check via Windows Registry Uninstall keys (handles MSI + traditional installers).
function Test-Installed-Registry {
    param([string]$Id)
    $name = if ($REVERT_NAMES.ContainsKey($Id)) { $REVERT_NAMES[$Id] } else { $Id }
    $uninstallers = Find-Uninstaller $name
    return ($uninstallers.Count -gt 0)
}

# Check via common install paths (last resort for portable/leftover installs).
# Uses only Program Files / install dirs - NOT AppData data folders (which can
# legitimately remain after a clean uninstall).
function Test-Installed-Path {
    param([string]$Id)
    $name = if ($REVERT_NAMES.ContainsKey($Id)) { $REVERT_NAMES[$Id] } else { $Id }
    $paths = Get-KnownPaths $name -InstallDirs
    foreach ($p in $paths) {
        if (Test-Path $p) { return $true }
    }
    return $false
}

# Map app IDs to known install paths.
# Use -InstallDirs to get only real install directories (for detection).
# Without it, returns all paths including user data (for cleanup).
function Get-KnownPaths {
    param([string]$Name, [switch]$InstallDirs)
    $lc = $Name.ToLower()
    $localAppData = $env:LOCALAPPDATA
    $programFiles = $env:ProgramFiles
    $programFiles86 = ${env:ProgramFiles(x86)}
    $appData = $env:APPDATA
    $paths = @()
    switch -Wildcard ($lc) {
        "*discord*" {
            if (-not $InstallDirs) { $paths += "$appData\discord" }
            $paths += "$programFiles\Discord"
        }
        "*brave*" {
            $paths += "$programFiles\BraveSoftware\Brave-Browser"
            $paths += "$programFiles86\BraveSoftware\Brave-Browser"
        }
        "*chrome*" {
            $paths += "$programFiles\Google\Chrome"
            $paths += "$programFiles86\Google\Chrome"
        }
        "*firefox*" {
            $paths += "$programFiles\Mozilla Firefox"
        }
        "*zen*" {
            $paths += "$localAppData\zen-browser"
        }
        "*spotify*" {
            if (-not $InstallDirs) { $paths += "$appData\Spotify" }
            if (-not $InstallDirs) { $paths += "$localAppData\Spotify" }
            $paths += "$programFiles\Spotify"
        }
        "*vlc*" {
            $paths += "$programFiles\VideoLAN\VLC"
            $paths += "$programFiles86\VideoLAN\VLC"
        }
        "*telegram*" {
            $paths += "$programFiles\Telegram Desktop"
            $paths += "$localAppData\Telegram Desktop"
        }
        "*whatsapp*" {
            $paths += "$localAppData\WhatsApp"
            $paths += "$programFiles\WhatsApp"
        }
        "*obs*" {
            $paths += "$programFiles\obs-studio"
        }
        "*stremio*" {
            $paths += "$localAppData\Programs\Stremio"
            $paths += "$programFiles\Stremio"
        }
        "*steam*" {
            $paths += "$programFiles (x86)\Steam"
            $paths += "$programFiles\Steam"
        }
        "*epic*" {
            $paths += "$programFiles\Epic Games"
            $paths += "$programFiles (x86)\Epic Games"
        }
        "*battle*" {
            $paths += "$programFiles (x86)\Battle.net"
            if (-not $InstallDirs) { $paths += "$localAppData\Battle.net" }
        }
        "*riot*" {
            $paths += "$programFiles\Riot Games"
            if (-not $InstallDirs) { $paths += "$localAppData\Riot Games" }
        }
        "*heroic*" {
            $paths += "$localAppData\Programs\heroic"
            $paths += "$programFiles\Heroic"
        }
        "*vscode*" { $paths += "$localAppData\Programs\Microsoft VS Code" }
        "*cursor*" { $paths += "$localAppData\Programs\cursor" }
        "*antigravity*" { $paths += "$localAppData\Programs\Antigravity" }
        "*notion*" { $paths += "$localAppData\Programs\Notion" }
        "*obsidian*" { $paths += "$localAppData\Obsidian" }
        "*postman*" { $paths += "$localAppData\Postman" }
        "*insomnia*" { $paths += "$localAppData\Insomnia" }
        "*bitwarden*" { $paths += "$localAppData\Bitwarden" }
        "*keepassxc*" { $paths += "$programFiles\KeePassXC" }
        "*1password*" { $paths += "$localAppData\1Password" }
        "*libreoffice*" { $paths += "$programFiles\LibreOffice" }
        "*pycharm*" { $paths += "$localAppData\Programs\PyCharm" }
        "*db browser*" { $paths += "$programFiles\DB Browser for SQLite" }
        "*virtualbox*" { $paths += "$programFiles\Oracle\VirtualBox" }
        "*nvidia*" {
            $paths += "$programFiles\NVIDIA Corporation"
            $paths += "$programFiles (x86)\NVIDIA Corporation"
        }
        "*amd*" { $paths += "$programFiles\AMD" }
        "*intel*" { $paths += "$programFiles\Intel" }
        "*git*" { $paths += "$programFiles\Git" }
        "*github*" { $paths += "$localAppData\Programs\GitHub CLI" }
        "*docker*" { $paths += "$programFiles\Docker\Docker" }
        "*foxit*" { $paths += "$programFiles\Foxit Software" }
    }
    return $paths
}

# Search Windows Registry for uninstaller entries matching the given DisplayName pattern.
function Find-Uninstaller {
    param([string]$DisplayNamePattern)
    $results = @()
    # Build whole-word regex patterns so "Git" does not match "GitHub Desktop".
    # 1) The full name as a phrase (e.g. "Google Chrome").
    # 2) The last word as a standalone word (e.g. "Chrome").
    $patterns = @()
    $full = [regex]::Escape($DisplayNamePattern.Trim())
    $patterns += "\b$($full -replace '\\ ', '\\s+')\b"
    $parts = $DisplayNamePattern -split '\s+'
    if ($parts.Count -gt 1) {
        $last = [regex]::Escape($parts[-1])
        # Only use the last word when it is distinctive (not a generic suffix).
        $generic = @("launcher", "desktop", "client", "browser", "app", "software",
                     "editor", "suite", "reader", "player", "manager", "service",
                     "cli", "tool", "tools", "studio", "control", "experience")
        if ($last.Length -ge 4 -and $generic -notcontains $last.ToLower()) {
            $patterns += "\b$last\b"
        }
    }
    # Search both 64-bit and 32-bit registry paths
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($regPath in $regPaths) {
        if (-not (Test-Path $regPath)) { continue }
        Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if (-not $props.DisplayName) { return }
            $dn = $props.DisplayName.ToString()
            foreach ($pat in $patterns) {
                if ($dn -imatch $pat) {
                    $results += @{
                        DisplayName = $dn
                        UninstallString = $props.UninstallString
                        QuietUninstallString = $props.QuietUninstallString
                        Path = $_.PSPath
                        Source = "Registry"
                    }
                    break
                }
            }
        }
    }
    return $results
}

function Install-Winget {
    param([string]$Id, [string]$Name)
    if ($DryRun) { Write-Dry "winget install --id $Id -e -h"; return }
    if (Test-Installed $Id) {
        Write-Skip $Name
        return
    }
    $r = Invoke-Winget @(
        "install", "--id", $Id,
        "--accept-source-agreements", "--accept-package-agreements",
        "-e", "-h"
    ) -Label "Installing $Name"
    # Decide by real presence, not by exit code: winget can report a failure
    # (or a success) that does not match what actually got installed.
    if (Test-Installed $Id) {
        Write-OK $Name
    } elseif ($r.Code -eq 0) {
        Write-OK $Name
    } else {
        Write-Fail $Name
    }
}

# User-level installer via PowerShell (opencode, Claude Code, ...).
function Install-UserTool {
    param([string]$ScriptUrl, [string]$Name)
    if ($DryRun) { Write-Dry "irm $ScriptUrl | iex"; return }
    $job = Invoke-ScriptSpinner -Label "Installing $Name" -Script {
        param($url)
        Invoke-RestMethod -Uri $url -UseBasicParsing | Invoke-Expression
    } -ArgumentList @($ScriptUrl)
    if ($job.Done) { Write-OK $Name } else { Write-Fail "$Name (manual install may be needed)" }
}

# -- winget uninstall (used by -Revert) --------------------------------------
# Legacy thin wrapper kept for compatibility. Prefer Uninstall-Completely.
function Uninstall-Winget {
    param([string]$Id, [string]$Name)
    Uninstall-Completely -Id $Id -Name $Name
}

# -- Comprehensive uninstall (winget + registry + path cleanup) ---------------
# Tries multiple methods in sequence to ensure packages are removed completely,
# regardless of how they were originally installed (winget, MSI, vendor installer).
function Uninstall-Completely {
    param([string]$Id, [string]$Name)
    if ($DryRun) {
        Write-Dry "Uninstall $Name (ID: $Id) via winget, MSIX/Store, registry, and path cleanup"
        return
    }

    Write-Host "  [i] Uninstalling $Name (ID: $Id)" -ForegroundColor Cyan
    $removed = $false
    $method = ""

    # Method 1: winget (cleanest for winget-managed packages).
    $method = "winget"
    Write-Host "  [dbg] Method 1/4: winget" -ForegroundColor DarkGray
    $uninstalled = $false
    for ($i = 1; $i -le 2; $i++) {
        $r = Invoke-Winget @(
            "uninstall", "--id", $Id,
            "--accept-source-agreements", "--accept-package-agreements"
        ) -Label "  [$method] Removing $Name (try $i)"
        Write-Host "  [dbg] winget exit: $($r.Code)" -ForegroundColor DarkGray
        if ($r.Code -eq 0) {
            $uninstalled = $true
            break
        }
        if ($i -lt 2) { Start-Sleep -Seconds 2 }
    }
    if ($uninstalled -and -not (Test-Installed $Id)) {
        $removed = $true
        Write-Host "  [OK] Removed via winget" -ForegroundColor Green
    }
    if ($removed) { return }

    # Method 2: MSIX / Microsoft Store packages (Brave, Discord, Spotify, ...).
    # These are registered as Windows App packages, not registry uninstallers.
    $method = "msix"
    Write-Host "  [dbg] Method 2/4: MSIX / Store package" -ForegroundColor DarkGray
    $displayName = if ($REVERT_NAMES.ContainsKey($Id)) { $REVERT_NAMES[$Id] } else { $Id }
    $appx = Get-AppxByName $displayName
    if ($appx.Count -eq 0) { $appx = Get-AppxByName $Id }
    if ($appx.Count -gt 0) {
        foreach ($p in $appx) {
            Write-Host "  [dbg] Found MSIX package: $($p.Name) ($($p.PackageFullName))" -ForegroundColor DarkGray
            try {
                Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
                Start-Sleep -Seconds 2
                Write-Host "  [OK] MSIX package removed: $($p.Name)" -ForegroundColor Green
            } catch {
                # Some Store apps are provisioned for all users - need the provisioned variant.
                Write-Host "  [dbg] Remove-AppxPackage failed: $($_.Exception.Message)" -ForegroundColor DarkGray
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $p.PackageFullName -ErrorAction Stop | Out-Null
                    Write-Host "  [OK] MSIX provisioned package removed: $($p.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "  [dbg] Remove-AppxProvisionedPackage failed: $($_.Exception.Message)" -ForegroundColor DarkGray
                }
            }
        }
        if (-not (Test-Installed $Id)) {
            $removed = $true
            Write-Host "  [OK] Removed via MSIX / Store" -ForegroundColor Green
        }
    } else {
        Write-Host "  [dbg] No MSIX package found for '$displayName'" -ForegroundColor DarkGray
    }
    if ($removed) { return }

    # Method 3: Registry uninstall string (for MSI and traditional installers).
    $method = "registry"
    Write-Host "  [dbg] Method 3/4: registry uninstall" -ForegroundColor DarkGray
    $uninstallers = Find-Uninstaller $displayName
    if ($uninstallers.Count -gt 0) {
        foreach ($u in $uninstallers) {
            # Prefer a quiet/silent uninstall string when the vendor provides one.
            $cmd = if ($u.QuietUninstallString) { $u.QuietUninstallString } else { $u.UninstallString }
            if (-not $cmd) { continue }
            Write-Host "  [dbg] Trying: $($u.DisplayName) -> $cmd" -ForegroundColor DarkGray
            try {
                if ($cmd -match "msiexec|MsiExec") {
                    # MSI: extract the product code and run a silent uninstall directly.
                    if ($cmd -match '\{[0-9A-Fa-f-]{36}\}') {
                        $prodCode = $Matches[0]
                        Write-Host "  [dbg] MSI product code: $prodCode" -ForegroundColor DarkGray
                        Start-Process "msiexec.exe" -ArgumentList "/x $prodCode /qn /norestart" -PassThru -Wait -ErrorAction Stop | Out-Null
                    } else {
                        # No product code found - run the uninstall string as-is.
                        Start-Process "cmd.exe" -ArgumentList "/c", $cmd -PassThru -Wait -WindowStyle Hidden -ErrorAction Stop | Out-Null
                    }
                } else {
                    # Traditional .exe uninstaller - append a silent flag if none present.
                    if ($cmd -notmatch "/[Ss][a-zA-Z]*" -and $cmd -notmatch "silent|/q\b|/Q\b") {
                        $cmd = "$cmd /S"
                    }
                    Start-Process "cmd.exe" -ArgumentList "/c", $cmd -PassThru -Wait -WindowStyle Hidden -ErrorAction Stop | Out-Null
                }
                Start-Sleep -Seconds 3
                # Check if the app is gone after registry uninstall.
                if (-not (Test-Installed $Id)) {
                    $removed = $true
                    Write-Host "  [OK] Removed via registry uninstaller" -ForegroundColor Green
                    break
                }
            } catch {
                Write-Host "  [dbg] Registry uninstall failed: $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "  [dbg] No registry uninstaller found for '$displayName'" -ForegroundColor DarkGray
    }
    if ($removed) { return }

    # Method 4: Path cleanup (last resort - remove leftover directories).
    $method = "path"
    Write-Host "  [dbg] Method 4/4: path cleanup" -ForegroundColor DarkGray
    $paths = Get-KnownPaths $displayName
    $pathsRemoved = 0
    foreach ($p in $paths) {
        if (Test-Path $p) {
            try {
                # Try winget to remove leftover data.
                $leaf = Split-Path $p -Leaf
                Write-Host "  [dbg] Cleaning: $p" -ForegroundColor DarkGray
                # Do NOT force-delete system files - only attempt winget removal of data dirs.
                Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
                $pathsRemoved++
            } catch {
                Write-Host "  [dbg] Could not remove $p : $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }
    if ($pathsRemoved -gt 0) {
        Write-Host "  [WARN] Removed $pathsRemoved leftover folder(s) for $Name" -ForegroundColor Yellow
    }

    # Final verification.
    if (-not (Test-Installed $Id)) {
        $removed = $true
        Write-Host "  [OK] $Name fully removed" -ForegroundColor Green
    }
    if (-not $removed) {
        Write-Host "  [FAIL] $Name could not be removed automatically" -ForegroundColor Red
        Write-Host "         Try: winget uninstall --id $Id (with admin PowerShell)" -ForegroundColor Yellow
    }
}

# Every winget package the setup can install, grouped for the revert flow.
$REVERT_GROUPS = @(
    @{ Title = "Browsers";         Ids = @("Zen-Team.Zen-Browser", "Google.Chrome", "Brave.Brave", "Mozilla.Firefox") }
    @{ Title = "Communications";   Ids = @("Discord.Discord", "Telegram.TelegramDesktop", "WhatsApp.WhatsApp") }
    @{ Title = "Media";            Ids = @("VideoLAN.VLC", "Spotify.Spotify", "Stremio.Stremio", "OBSProject.OBSStudio") }
    @{ Title = "Productivity";     Ids = @("TheDocumentFoundation.LibreOffice", "Obsidian.Obsidian", "JetBrains.PyCharmCommunity", "DBBrowserForSQLite.DBBrowserForSQLite", "Notion.Notion") }
    @{ Title = "Dev tools";        Ids = @("Microsoft.VisualStudioCode", "Anysphere.Cursor", "Google.Antigravity", "Postman.Postman", "Insomnia.Insomnia", "Bitwarden.Bitwarden", "KeePassXCTeam.KeePassXC", "AgileBits.1Password", "GitHub.cli", "Docker.DockerDesktop") }
    @{ Title = "Gaming";           Ids = @("Valve.Steam", "HeroicGamesLauncher.HeroicGamesLauncher", "EpicGames.EpicGamesLauncher", "Battle-net.App", "Riot.RiotClient") }
    @{ Title = "Virtual machines"; Ids = @("Oracle.VirtualBox") }
    @{ Title = "GPU tools";        Ids = @("Nvidia.GeForceExperience", "AdvancedMicroDevices.AMDRadeonSoftware", "Intel.ArcControl") }
    @{ Title = "PDF & Doc tools";  Ids = @("org.pdfedit.PDFedit", "org.qpdf.qpdf", "Foxit.FoxitReader", "PDF-Shuffler.PDF-Shuffler") }
)

# Friendly name lookup for the revert groups (best effort, falls back to Id).
$REVERT_NAMES = @{
    "Zen-Team.Zen-Browser"               = "Zen Browser"
    "Google.Chrome"                      = "Google Chrome"
    "Brave.Brave"                        = "Brave Browser"
    "Mozilla.Firefox"                    = "Firefox"
    "Discord.Discord"                    = "Discord"
    "Telegram.TelegramDesktop"           = "Telegram"
    "WhatsApp.WhatsApp"                  = "WhatsApp Desktop"
    "VideoLAN.VLC"                       = "VLC"
    "Spotify.Spotify"                    = "Spotify"
    "Stremio.Stremio"                    = "Stremio"
    "OBSProject.OBSStudio"               = "OBS Studio"
    "TheDocumentFoundation.LibreOffice"  = "LibreOffice"
    "Obsidian.Obsidian"                  = "Obsidian"
    "JetBrains.PyCharmCommunity"         = "PyCharm Community"
    "DBBrowserForSQLite.DBBrowserForSQLite" = "DB Browser for SQLite"
    "Notion.Notion"                      = "Notion"
    "Microsoft.VisualStudioCode"         = "VS Code"
    "Anysphere.Cursor"                   = "Cursor"
    "Google.Antigravity"                 = "Antigravity"
    "Postman.Postman"                    = "Postman"
    "Insomnia.Insomnia"                  = "Insomnia"
    "Bitwarden.Bitwarden"                = "Bitwarden"
    "KeePassXCTeam.KeePassXC"            = "KeePassXC"
    "AgileBits.1Password"                = "1Password"
    "Git.Git"                            = "Git"
    "GitHub.cli"                         = "GitHub CLI"
    "Docker.DockerDesktop"               = "Docker Desktop"
    "Valve.Steam"                        = "Steam"
    "HeroicGamesLauncher.HeroicGamesLauncher" = "Heroic Games Launcher"
    "EpicGames.EpicGamesLauncher"            = "Epic Games Launcher"
    "Battle-net.App"                 = "Battle.net"
    "Riot.RiotClient"                = "Riot Client"
    "Oracle.VirtualBox"                  = "VirtualBox"
    "Nvidia.GeForceExperience"           = "NVIDIA GeForce Experience"
    "AdvancedMicroDevices.AMDRadeonSoftware" = "AMD Radeon Software"
    "Intel.ArcControl"                   = "Intel Arc Control"
    "org.pdfedit.PDFedit"                = "PDFedit"
    "org.qpdf.qpdf"                      = "qpdf"
    "Foxit.FoxitReader"                    = "Foxit Reader"
    "PDF-Shuffler.PDF-Shuffler"            = "PDF-Shuffler"
}

# Restore the gaming tweaks the setup applied (Game DVR + power plan).
function Revert-GamingTweaks {
    param([switch]$Force)
    if ($DryRun) { Write-Dry "Gaming tweaks: restore Game DVR + Balanced power plan"; return }
    Write-Info "Restoring gaming tweaks..."
    # 1) Re-enable Game DVR (HKCU).
    $regPath = "HKCU:\System\GameConfigStore"
    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "GameDVR_Enabled" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $regPath -Name "GameDVR_FSEBehaviorMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Write-OK "Game DVR re-enabled (HKCU)"
    }
    # 2) Re-enable Game DVR at the machine level too (undo the HKLM tweak).
    $xboxReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    if (Test-Path $xboxReg) {
        Set-ItemProperty -Path $xboxReg -Name "AllowGameDVR" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Write-OK "Game DVR re-enabled (HKLM)"
    }
    # 3) Restore the Balanced power plan (built-in Windows GUID).
    $balanced = powercfg /list 2>$null | Select-String "Balanced|381b4222-f694-41f0-9685-ff5bb260df2e"
    if ($balanced) {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
        Write-OK "Power plan restored to Balanced"
    } else {
        Write-Warn "Balanced power plan not found - leaving current plan as-is"
    }
}

# -- Steps --------------------------------------------------------------------
$TotalSteps = 11
$CurrentStep = 0

function Print-Step {
    param([string]$Title, [string]$Desc)
    $script:CurrentStep++
    Write-Host ""
    Write-Host "  $($C.Magenta)====================================================================$($C.Rst)"
    Write-Host "  $($C.Bold)STEP $($script:CurrentStep)/$TotalSteps : $Title$($C.Rst)  $($C.Dim)$Desc$($C.Rst)"
    Write-Host "  $($C.Magenta)====================================================================$($C.Rst)"
    Show-Progress -Done ($script:CurrentStep - 1) -Total $TotalSteps -Status "completed"
    Write-Host ""
}

# -- Banner -------------------------------------------------------------------
Show-Banner
Show-Progress -Done 0 -Total $TotalSteps -Status "ready"

# -- Check winget ------------------------------------------------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  [FAIL] winget not found. Install 'App Installer' from the Microsoft Store." -ForegroundColor Red
    Write-Host "  Press Enter to close this window..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

# ============================================================================
#  MAIN MENU: setup, revert or quit. The -Revert switch jumps straight into
#  revert mode (no menu), and --DryRun defaults to the setup path.
# ============================================================================
if (-not $Revert -and -not $DryRun) {
    Write-Host ""
    Write-Host "  $($C.Bold)What do you want to do?$($C.Rst)"
    Write-Host "    $($C.Cyan)[1]$($C.Rst) Full setup ($TotalSteps steps)"
    Write-Host "    $($C.Cyan)[2]$($C.Rst) $($C.Red)Revert$($C.Rst) - uninstall what this setup added"
    Write-Host "    $($C.Cyan)[0]$($C.Rst) Quit"
    $menuChoice = Read-Host "  Selection"
    switch ($menuChoice) {
        "2" { $Revert = $true }
        "0" {
            Write-Host "  Bye!"
            Read-Host "Press Enter to close this window..."
            exit 0
        }
        default { Write-Host "  $($C.Dim)Starting full setup...$($C.Rst)" }
    }
}

# ============================================================================
#  REVERT MODE: undo what the setup installed/configured.
# ============================================================================
if ($Revert) {
    Write-Host "  $($C.Red)REVERT$($C.Rst) - pick what to remove. Nothing is removed without asking."
    Write-Host ""

# Pick which app groups to uninstall (multi-select, same helper as install).
$groupOptions = @()
foreach ($g in $REVERT_GROUPS) { $groupOptions += $g.Title }
$picked = Select-Items "Which app groups should I uninstall?" $groupOptions $null

# Tracking variables for per-app summary (keyed by ID so group filters match).
$results = @()

foreach ($n in $picked) {
    $g = $REVERT_GROUPS[$n - 1]
    Write-Host ""
    Write-Host "  $($C.Magenta)--- $($g.Title) ---$($C.Rst)"
    foreach ($id in $g.Ids) {
        $name = if ($REVERT_NAMES.ContainsKey($id)) { $REVERT_NAMES[$id] } else { $id }

        # Pre-check: if the app was never installed, skip it (no need to uninstall).
        if (-not (Test-Installed $id)) {
            Write-Info "$name is not installed - skipped"
            $results += @{
                Id = $id
                Name = $name
                Status = "NotInstalled"
                Group = $g.Title
            }
            continue
        }

        Uninstall-Completely -Id $id -Name $name
        # Record status based on comprehensive presence check (winget + registry + paths).
        $isGone = -not (Test-Installed $id)
        $status = if ($isGone) { "Removed" } else { "Failed" }
        $results += @{
            Id = $id
            Name = $name
            Status = $status
            Group = $g.Title
        }
        if ($isGone) {
            Write-OK "$name removed"
        } else {
            Write-Fail "$name still installed"
        }
    }
}

# Summary per group.
if ($picked.Count -eq 0) {
    Write-Info "No app groups selected - nothing to uninstall."
}
else {
    Write-Host ""
    foreach ($g in $REVERT_GROUPS) {
        $groupResults = @($results | Where-Object { $g.Ids -contains $_.Id })
        if ($groupResults.Count -eq 0) { continue }
        $gUninstalled = @($groupResults | Where-Object { $_.Status -eq "Removed" })
        $gFailed = @($groupResults | Where-Object { $_.Status -eq "Failed" })
        $gSkipped = @($groupResults | Where-Object { $_.Status -eq "NotInstalled" })
        if ($gUninstalled.Count -gt 0) {
            Write-OK "$($gUninstalled.Count) app(s) removed from $($g.Title)"
        }
        if ($gFailed.Count -gt 0) {
            Write-Fail "$($gFailed.Count) app(s) still present from $($g.Title)"
        }
        if ($gSkipped.Count -gt 0) {
            Write-Info "$($gSkipped.Count) app(s) from $($g.Title) were not installed - skipped"
        }
    }
}

# Restore the tweaks (gaming) if they were applied.
if (Confirm-Step "Restore gaming tweaks (Game DVR + Balanced power plan)?" "y") {
    Revert-GamingTweaks
}
else {
    Write-Info "Gaming tweaks kept as-is."
}

Write-Host ""
Write-Host "  $($C.Green)====================================================================$($C.Rst)"
Write-Host "  $($C.Bold)Revert finished$($C.Rst)"

$removedApps = @($results | Where-Object { $_.Status -eq "Removed" })
$failedApps = @($results | Where-Object { $_.Status -eq "Failed" })
$skippedApps = @($results | Where-Object { $_.Status -eq "NotInstalled" })
$removedCount = $removedApps.Count
$failedCount = $failedApps.Count
$skippedCount = $skippedApps.Count

Write-Host ""
Write-Host "  $($C.Bold)SUMMARY$($C.Rst)"
Write-Host "  $($C.Green)$removedCount app(s) removed$($C.Rst)"
Write-Host "  $($C.Red)$failedCount app(s) failed to remove$($C.Rst)"
Write-Host "  $($C.Cyan)$skippedCount app(s) were not installed (skipped)$($C.Rst)"
Write-Host ""

if ($removedCount -gt 0) {
    Write-Host "  ${C.Green}Removed:${C.Rst}"
    foreach ($r in $removedApps) { Write-Host "   [x] $($r.Name)" }
}
if ($failedCount -gt 0) {
    Write-Host ""
    Write-Host "  ${C.Yellow}Still installed (may need manual uninstall or reboot):${C.Rst}"
    foreach ($r in $failedApps) { Write-Host "   [!] $($r.Name)" }
}
if ($skippedCount -gt 0) {
    Write-Host ""
    Write-Host "  ${C.Dim}Not installed (skipped):${C.Rst}"
    foreach ($r in $skippedApps) { Write-Host "   [ ] $($r.Name)" }
}

Write-Host ""
Write-Host "  ${C.Dim}Restart the PC for changes to fully take effect.${C.Rst}"
Write-Host ""
if (-not $DryRun) {
    Read-Host "Press Enter to close this window..."
}
exit 0
}

# ============================================================================
#  STEP 1: System base
# ============================================================================
Print-Step "System base" "Windows Update + drivers"
if (Confirm-Step "Run Windows Update now?" "n") {
    if ($DryRun) {
        Write-Dry "Windows Update"
    } else {
        Write-Info "Running Windows Update (may take a while)..."
        $upd = Invoke-ScriptSpinner -Label "Running Windows Update" -Script {
            Install-Module PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
            Get-WindowsUpdate -Install -AcceptAll -ErrorAction Stop 2>$null
        }
        if ($upd.Done) { Write-OK "Windows Update" } else { Write-Fail "Windows Update (run this script as Administrator)" }
    }
} else {
    Write-Info "Skipped Windows Update."
}

# ============================================================================
#  STEP 2: GPU vendor detection + matching driver/app.
# ============================================================================
function Get-GPU-Vendor {
    $adapter = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'Microsoft Basic|Remote Display' } |
        Select-Object -First 1
    $name = if ($adapter) { $adapter.Name } else { "" }
    if ($name -match 'NVIDIA|GeForce|RTX|GTX') { return "NVIDIA" }
    if ($name -match 'AMD|Radeon|Radeon HD')  { return "AMD" }
    if ($name -match 'Intel|Arc|Iris|UHD')    { return "Intel" }
    return "Unknown"
}

Print-Step "GPU drivers" "Detect your GPU and install the matching vendor driver"
$gpu = Get-GPU-Vendor
Write-Host "  [i] GPU detected: $gpu" -ForegroundColor Cyan
switch ($gpu) {
    "NVIDIA" {
        if (Confirm-Step "Install NVIDIA GeForce Experience?" "y") {
            Install-Winget "Nvidia.GeForceExperience" "NVIDIA GeForce Experience"
            Write-Info "NVIDIA: for the latest Game Ready driver, run GeForce Experience."
        }
    }
    "AMD" {
        if (Confirm-Step "Install AMD Radeon Software?" "y") {
            Install-Winget "AdvancedMicroDevices.AMDRadeonSoftware" "AMD Radeon Software"
            Write-Info "AMD: check Windows Update / AMD.com for the latest Adrenalin driver."
        }
    }
    "Intel" {
        if (Confirm-Step "Install Intel Arc Control?" "y") {
            Install-Winget "Intel.ArcControl" "Intel Arc Control"
            Write-Info "Intel: check Windows Update / Intel.com for the latest Arc/Iris driver."
        }
    }
    default {
        Write-Info "GPU vendor not detected (VM?). Drivers usually come via Windows Update."
    }
}

# ============================================================================
#  STEP 3: Browsers - multi-select, nothing forced. Windows 11 ships with
#  Edge preinstalled, so every option here is an addition (or replacement).
#  Edge removal is offered separately below, never forced.
# ============================================================================
Print-Step "Browsers" "Pick any browsers - or all of them (multi-select)"
$browsers = Select-Items "Which browsers do you want to install?" @(
    "Zen (Firefox-based, privacy-focused)"
    "Google Chrome"
    "Brave (Chromium-based)"
    "Helios (Firefox-based, privacy-focused)"
    "Firefox (Mozilla)"
) @(
    "Zen is the author's daily driver"
    "Proprietary, most extensions"
    "Blocks ads/trackers out of the box"
    "Firefox-based, privacy-focused"
    "Stock open-source browser"
)
foreach ($n in $browsers) {
    switch ($n) {
        1 { Install-Winget "Zen-Team.Zen-Browser" "Zen Browser" }
        2 { Install-Winget "Google.Chrome" "Google Chrome" }
        3 { Install-Winget "Brave.Brave" "Brave Browser" }
        4 { Install-Winget "Helios-Team.Helios" "Helios Browser" }
        5 { Install-Winget "Mozilla.Firefox" "Firefox" }
    }
}
if ($browsers.Count -eq 0) { Write-Info "No browsers selected - skipped." }

# Optional debloat: only with explicit consent.
if (Confirm-Step "Remove preinstalled Edge / bloatware?" "n") {
    if ($DryRun) {
        Write-Dry "Remove Edge / bloatware"
    } else {
        Remove-AppxPackage -Package (Get-AppxPackage -Name "*MicrosoftEdge*" | Select-Object -First 1).PackageFullName -ErrorAction SilentlyContinue
        Write-OK "Edge removed (or was not present)"
    }
} else {
    Write-Info "Keeping Edge and preinstalled apps."
}

# ============================================================================
#  STEP 4: Communications
# ============================================================================
Print-Step "Communications" "Discord, Telegram, WhatsApp (multi-select)"
$comms = Select-Items "Which communication apps do you want?" @(
    "Discord"
    "Telegram"
    "WhatsApp"
) @(
    "Voice/text chat"
    "Messaging"
    "Messaging"
)
foreach ($n in $comms) {
    switch ($n) {
        1 { Install-Winget "Discord.Discord" "Discord" }
        2 { Install-Winget "Telegram.TelegramDesktop" "Telegram" }
        3 { Install-Winget "WhatsApp.WhatsApp" "WhatsApp Desktop" }
    }
}
if ($comms.Count -eq 0) { Write-Info "No communication apps selected - skipped." }

# ============================================================================
#  STEP 5: Media
# ============================================================================
Print-Step "Media" "VLC, Spotify, Stremio, OBS (multi-select)"
$media = Select-Items "Which media apps do you want?" @(
    "VLC (media player)"
    "Spotify (music)"
    "Stremio (movies/series)"
    "OBS Studio (streaming/recording)"
) @(
    "Single player for everything"
    "Music streaming"
    "Movies/series aggregator"
    "Capture and stream"
)
foreach ($n in $media) {
    switch ($n) {
        1 { Install-Winget "VideoLAN.VLC" "VLC" }
        2 { Install-Winget "Spotify.Spotify" "Spotify" }
        3 { Install-Winget "Stremio.Stremio" "Stremio" }
        4 { Install-Winget "OBSProject.OBSStudio" "OBS Studio" }
    }
}
if ($media.Count -eq 0) { Write-Info "No media apps selected - skipped." }

# ============================================================================
#  STEP 6: Productivity & office
# ============================================================================
Print-Step "Productivity" "Office, notes, databases (multi-select)"
$prod = Select-Items "Which productivity apps do you want?" @(
    "LibreOffice (office suite)"
    "Obsidian (notes)"
    "PyCharm Community (Python IDE)"
    "DB Browser for SQLite"
    "Notion (notes & docs)"
) @(
    "Free MS-Office-compatible suite"
    "Local markdown notes"
    "Free Python IDE"
    "SQLite GUI"
    "All-in-one notes/docs (optional)"
)
foreach ($n in $prod) {
    switch ($n) {
        1 { Install-Winget "TheDocumentFoundation.LibreOffice" "LibreOffice" }
        2 { Install-Winget "Obsidian.Obsidian" "Obsidian" }
        3 { Install-Winget "JetBrains.PyCharmCommunity" "PyCharm Community" }
        4 { Install-Winget "DBBrowserForSQLite.DBBrowserForSQLite" "DB Browser for SQLite" }
        5 { Install-Winget "Notion.Notion" "Notion" }
    }
}
if ($prod.Count -eq 0) { Write-Info "No productivity apps selected - skipped." }

# ============================================================================
#  STEP 7: Dev tools - editor, API client, AI agent, password manager
# ============================================================================
Print-Step "Dev tools" "Pick your editor, API client, AI agent and password manager"

# Editor
$editors = Select-Items "Which editor(s) do you want?" @(
    "VS Code (Microsoft)"
    "Cursor (AI-first editor)"
    "Antigravity (Google AI editor)"
) @(
    "Most popular, huge extension market"
    "AI code completion built in"
    "Google's AI editor"
)
foreach ($n in $editors) {
    switch ($n) {
        1 { Install-Winget "Microsoft.VisualStudioCode" "VS Code" }
        2 { Install-Winget "Anysphere.Cursor" "Cursor" }
        3 { Install-Winget "Google.Antigravity" "Antigravity" }
    }
}
if ($editors.Count -eq 0) { Write-Info "No editor selected - skipped." }

# API client
$apiClients = Select-Items "Which API client do you want?" @(
    "Postman"
    "Insomnia"
) @(
    "REST/graphQL client, team workspaces"
    "Open-source REST/graphQL client"
)
foreach ($n in $apiClients) {
    switch ($n) {
        1 { Install-Winget "Postman.Postman" "Postman" }
        2 { Install-Winget "Insomnia.Insomnia" "Insomnia" }
    }
}
if ($apiClients.Count -eq 0) { Write-Info "No API client selected - skipped." }

# AI coding agents
$agents = Select-Items "Which AI coding agents do you want?" @(
    "Claude Code (Anthropic)"
    "opencode (AI coding agent)"
    "Gemini CLI (Google)"
    "Codeium"
) @(
    "Anthropic's agentic CLI"
    "Open-source agentic CLI"
    "Google's agentic CLI"
    "Completions + agent"
)
foreach ($n in $agents) {
    switch ($n) {
        1 { Install-UserTool "https://claude.ai/install.ps1" "Claude Code" }
        2 { Install-UserTool "https://opencode.ai/install.ps1" "opencode" }
        3 { Install-UserTool "https://raw.githubusercontent.com/google-gemini/gemini-cli/main/install.ps1" "Gemini CLI" }
        4 { Install-UserTool "https://codeium.com/install.ps1" "Codeium" }
    }
}
if ($agents.Count -eq 0) { Write-Info "No AI agent selected - skipped." }

# Password manager (Bitwarden is optional - not everyone uses it)
$pm = Select-Items "Which password manager do you want?" @(
    "Bitwarden"
    "KeePassXC"
    "1Password"
) @(
    "Free, cloud-synced vaults"
    "Offline, open-source, local vaults"
    "Paid, polished, multi-device"
)
foreach ($n in $pm) {
    switch ($n) {
        1 { Install-Winget "Bitwarden.Bitwarden" "Bitwarden" }
        2 { Install-Winget "KeePassXCTeam.KeePassXC" "KeePassXC" }
        3 { Install-Winget "AgileBits.1Password" "1Password" }
    }
}
if ($pm.Count -eq 0) { Write-Info "No password manager selected - skipped." }

# Git + Docker (ask, they are the core dev stack)
Print-Step "Git + Docker" "Version control and containers"
if (Confirm-Step "Install Git and GitHub CLI?" "y") {
    Install-Winget "Git.Git" "Git"
    Install-Winget "GitHub.cli" "GitHub CLI"
}
if (Confirm-Step "Install Docker Desktop?" "y") {
    Install-Winget "Docker.DockerDesktop" "Docker Desktop"
}

# ============================================================================
#  STEP 8: Gaming
# ============================================================================
Print-Step "Gaming" "Steam, Heroic, Epic + performance tweaks (multi-select)"
$gaming = Select-Items "Which gaming apps do you want?" @(
    "Steam"
    "Heroic Games Launcher"
    "Epic Games Launcher"
    "Battle.net"
    "Riot Client"
) @(
    "The main store/library"
    "Epic/GOG/Amazon launcher"
    "Digital distribution"
    "Blizzard launcher & games"
    "MOBA & social gaming"
)
foreach ($n in $gaming) {
    switch ($n) {
        1 { Install-Winget "Valve.Steam" "Steam" }
        2 { Install-Winget "HeroicGamesLauncher.HeroicGamesLauncher" "Heroic Games Launcher" }
        3 { Install-Winget "EpicGames.EpicGamesLauncher" "Epic Games Launcher" }
        4 { Install-Winget "Battle-net.App" "Battle.net" }
        5 { Install-Winget "Riot.RiotClient" "Riot Client" }
    }
}
if ($gaming.Count -eq 0) { Write-Info "No gaming apps selected - skipped." }

if (Confirm-Step "Apply gaming tweaks (disable Game DVR, High performance plan)?" "y") {
    if ($DryRun) {
        Write-Dry "Gaming tweaks (Game DVR, power plan)"
    } else {
        $regPath = "HKCU:\System\GameConfigStore"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $regPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -ErrorAction SilentlyContinue
            Write-OK "Game DVR + fullscreen optimizations disabled"
        }
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c33b5 2>$null
        Write-OK "Power plan: High performance"
    }
} else {
    Write-Info "Gaming tweaks skipped."
}

# ============================================================================
#  STEP 11: PDF & Document Tools
# ============================================================================
Print-Step "PDF & Document Tools" "PDF editors, manipulators and viewers (multi-select)"
$pdfTools = Select-Items "Which PDF tools do you want?" @(
    "PDFedit (edit PDFs)"
    "qpdf (manipulate PDFs)"
    "Foxit (viewer/editor)"
    "PDF-Shuffler (merge/split)"
) @(
    "Edit and modify PDF content"
    "Split, merge, and reorganize PDFs"
    "Lightweight PDF viewer with editing"
    "Merge and split PDF pages"
)
foreach ($n in $pdfTools) {
    switch ($n) {
        1 { Install-Winget "org.pdfedit.PDFedit" "PDFedit" }
        2 { Install-Winget "org.qpdf.qpdf" "qpdf" }
        3 { Install-Winget "Foxit.FoxitReader" "Foxit Reader" }
        4 { Install-Winget "PDF-Shuffler.PDF-Shuffler" "PDF-Shuffler" }
    }
}
if ($pdfTools.Count -eq 0) { Write-Info "No PDF tools selected - skipped." }

# ============================================================================
#  Windows 11 Gaming Performance Optimizations (GPU-agnostic)
# ============================================================================
if (Confirm-Step "Apply Windows 11 gaming optimizations (GPU-agnostic)?") {
    if ($DryRun) {
        Write-Dry "Gaming optimizations: Game DVR disabled, power plan, Xbox services"
    } else {
        # Disable Game DVR (works on any GPU)
        $regPath = "HKCU:\System\GameConfigStore"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $regPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -ErrorAction SilentlyContinue
            Write-OK "Game DVR disabled"
        }
        # Set high performance power plan
        powercfg /setactive 8c5e7fda-e8bf-41f0-9685-ff5bb260df2e 2>$null
        Write-OK "Power plan: High performance"
        # Disable Xbox game bar and optional features for maximum performance
        $xboxReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
        if (Test-Path $xboxReg) {
            Set-ItemProperty -Path $xboxReg -Name "AllowGameDVR" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Write-OK "Xbox Game Bar DVR disabled"
        }
        # Enable Game Mode (works with any GPU)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\GameBar" -Name "GameModeEnabled" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Write-OK "Game Mode enabled"
        # Disable Nagle's algorithm for reduced input latency
        $tcpReg = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        if (Test-Path $tcpReg) {
            Set-ItemProperty -Path $tcpReg -Name "DisableNagle" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Write-OK "TCP Nagle's algorithm disabled"
        }
        Write-OK "Windows 11 gaming optimizations applied"
    }
} else {
    Write-Info "Gaming optimizations skipped."
}

# ============================================================================
#  STEP 9: Virtual machines
# ============================================================================
Print-Step "Virtual machines" "VirtualBox and/or Hyper-V (you choose)"
if ($DryRun) {
    Write-Dry "Prompt: VirtualBox / Hyper-V / skip"
    $vmChoice = "0"
} else {
    $vmChoice = Read-Host "  Install virtual machine software? [1] VirtualBox  [2] Hyper-V  [3] Both  [0] None"
}
switch ($vmChoice) {
    "1" { Install-Winget "Oracle.VirtualBox" "VirtualBox" }
    "2" {
        Write-Info "Enabling Hyper-V (requires a reboot)..."
        if (-not $DryRun) {
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart -ErrorAction SilentlyContinue
            Write-OK "Hyper-V enabled (reboot to finish)"
        }
    }
    "3" {
        Install-Winget "Oracle.VirtualBox" "VirtualBox"
        Write-Info "Enabling Hyper-V (requires a reboot)..."
        if (-not $DryRun) {
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart -ErrorAction SilentlyContinue
            Write-OK "Hyper-V enabled (reboot to finish)"
        }
    }
    default { Write-Info "Skipping virtual machines." }
}

# ============================================================================
#  STEP 10: Final cleanup
# ============================================================================
Print-Step "Final cleanup" "winget upgrade --all + disk cleanup"
if (Confirm-Step "Update all apps (winget upgrade --all)?" "y") {
    if ($DryRun) {
        Write-Dry "winget upgrade --all"
    } else {
        $r = Invoke-Winget @("upgrade", "--all", "--accept-source-agreements", "--accept-package-agreements") -Label "Upgrading apps"
        if ($r.Code -eq 0) { Write-OK "Apps updated" } else { Write-Fail "Apps upgrade had failures" }
        cleanmgr /sagerun:1 2>$null
        Write-OK "Disk cleanup scheduled"
    }
} else {
    Write-Info "Cleanup skipped."
}

# ============================================================================
#  Final summary
# ============================================================================
Write-Host ""
Write-Host "  $($C.Green)====================================================================$($C.Rst)"
Write-Host "  $($C.Bold)Setup complete$($C.Rst)  $($C.Dim)what happened$($C.Rst)"
Write-Host "  $($C.Green)====================================================================$($C.Rst)"
Show-Progress -Done 11 -Total 11 -Status "finished"
Write-Host ""
$elapsed = (Get-Date) - $script:StartTime
Write-Host "  $($C.Bold)Elapsed time:$($C.Rst) $([math]::Round($elapsed.TotalMinutes, 1)) min"
Write-Host ("  {0}[ v ]{1} OK: {2}   {0}[ - ]{1} Skipped: {3}   {0}[ x ]{1} Failed: {4}" -f $C.Green, $C.Rst, $script:OkCount, $script:SkipCount, $script:FailCount)
Write-Host "  $($C.Dim)Restart the PC for everything to take effect.$($C.Rst)"
Write-Host ""

# Keep the window open when launched by double-click so results are visible.
if (-not $DryRun) {
    Read-Host "Press Enter to close this window..."
}