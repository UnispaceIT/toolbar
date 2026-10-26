# Shared helpers for install.ps1 / uninstall.ps1. Dot-sourced, not run directly.

$ExtensionName = 'Unispace'
$RepoUrl       = 'https://github.com/UnispaceIT/toolbar.git'
$Branch        = 'main'

# pyRevit clones third-party extensions to %APPDATA%\pyRevit\Extensions\<Name>.extension
# (PyRevitConsts.DefaultExtensionsPath). This is the only copy these scripts manage;
# a copy anywhere else (e.g. a developer's working clone) is never modified.
$ExtensionsRoot = Join-Path $env:APPDATA 'pyRevit\Extensions'
$ManagedPath    = Join-Path $ExtensionsRoot "$ExtensionName.extension"

$LogFile = Join-Path $env:LOCALAPPDATA 'Unispace\Logs\toolbar-install.log'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    # Write-Host, not Write-Output, so log lines don't leak into function return values.
    Write-Host $line
    try {
        $dir = Split-Path $LogFile
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force -WhatIf:$false | Out-Null }
        Add-Content -Path $LogFile -Value $line -Encoding UTF8 -WhatIf:$false
    } catch { }
}

function Find-PyRevit {
    # PATH in this process may predate a pyRevit install that Intune ran moments ago
    # as a dependency, so rebuild it from the registry before looking.
    $env:Path = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User')
    ) -join ';'

    $cmd = Get-Command 'pyrevit.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:APPDATA           'pyRevit-Master\bin\pyrevit.exe'),
        (Join-Path $env:ProgramData       'pyRevit-Master\bin\pyrevit.exe'),
        (Join-Path $env:ProgramFiles      'pyRevit-Master\bin\pyrevit.exe'),
        (Join-Path $env:ProgramFiles      'pyRevit CLI\pyrevit.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'pyRevit CLI\pyrevit.exe')
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) { return $path }
    }
    return $null
}

function Invoke-PyRevit {
    # Runs the pyRevit CLI, logs its output, returns $true on exit code 0.
    param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string[]]$Arguments)
    Write-Log "> pyrevit $($Arguments -join ' ')"
    # Windows PowerShell 5.1 turns native stderr into terminating errors under 'Stop'.
    $ErrorActionPreference = 'Continue'
    $output = & $Exe @Arguments 2>&1
    $code = $LASTEXITCODE
    foreach ($line in $output) {
        $text = "$line".Trim()
        if ($text) { Write-Log "  $text" }
    }
    if ($code -ne 0) { Write-Log "  pyrevit exited with code $code" 'WARN' }
    return ($code -eq 0)
}

function Get-RegisteredExtensionPath {
    # Where pyRevit thinks the extension is installed, or $null if it isn't registered.
    # Parses lines like: Unispace | Type: UIExtension | Repo: "..." | Installed: "C:\...\x.extension"
    param([Parameter(Mandatory)][string]$Exe)
    $ErrorActionPreference = 'Continue'
    $output = & $Exe extensions 2>&1
    foreach ($line in $output) {
        $text = "$line"
        if ($text -match "^\s*$([regex]::Escape($ExtensionName))\s*\|" -and $text -match 'Installed:\s*"([^"]+)"') {
            return $Matches[1]
        }
    }
    return $null
}

function Test-SamePath {
    param([string]$A, [string]$B)
    if (-not $A -or -not $B) { return $false }
    $norm = { param($p) [IO.Path]::GetFullPath($p).TrimEnd('\') }
    return (& $norm $A) -ieq (& $norm $B)
}

function Get-CloneOriginUrl {
    # The 'origin' URL from a clone's .git\config, or $null. Read as text because
    # employee machines usually have no git.exe (pyRevit bundles its own git library).
    param([Parameter(Mandatory)][string]$Path)
    $config = Join-Path $Path '.git\config'
    if (-not (Test-Path $config)) { return $null }
    $inOrigin = $false
    foreach ($line in (Get-Content -Path $config -ErrorAction SilentlyContinue)) {
        if ($line -match '^\s*\[') { $inOrigin = $line -match '^\s*\[remote\s+"origin"\]' ; continue }
        if ($inOrigin -and $line -match '^\s*url\s*=\s*(.+?)\s*$') { return $Matches[1] }
    }
    return $null
}

function Test-IsCurrentRepo {
    # True if $Url is $RepoUrl, ignoring case, a trailing '.git' or '/', and a 'user@' prefix.
    # Installs from the old Unispace365/toolbar repo return $false.
    param([string]$Url)
    if (-not $Url) { return $false }
    $norm = { param($u) (($u.Trim() -replace '^(https?://)[^/@]+@', '$1') -replace '/+$', '' -replace '\.git$', '').ToLowerInvariant() }
    return (& $norm $Url) -eq (& $norm $RepoUrl)
}
