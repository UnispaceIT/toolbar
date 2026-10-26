# Intune custom detection script for the Unispace pyRevit toolbar.
# Upload this in the app's Detection rules; it is not part of the .intunewin package.
# Intune treats "exit 0 with output on STDOUT" as installed; anything else as not installed.
#
# An install that still pulls from the old Unispace365/toolbar repo counts as NOT
# installed, so Intune runs install.ps1 on it and it gets re-cloned from the new repo.

# Keep in sync with $RepoUrl in package\common.ps1 (this file is uploaded on its own).
$RepoUrl = 'https://github.com/UnispaceIT/toolbar'

$ext    = Join-Path $env:APPDATA 'pyRevit\Extensions\Unispace.extension'
$config = Join-Path $ext '.git\config'

if (-not ((Test-Path (Join-Path $ext 'extension.json')) -and (Test-Path $config))) { exit 1 }

# Read the 'origin' URL as text; employee machines usually have no git.exe.
$origin = $null
$inOrigin = $false
foreach ($line in (Get-Content -Path $config -ErrorAction SilentlyContinue)) {
    if ($line -match '^\s*\[') { $inOrigin = $line -match '^\s*\[remote\s+"origin"\]'; continue }
    if ($inOrigin -and $line -match '^\s*url\s*=\s*(.+?)\s*$') { $origin = $Matches[1]; break }
}

$norm = { param($u) (($u.Trim() -replace '^(https?://)[^/@]+@', '$1') -replace '/+$', '' -replace '\.git$', '').ToLowerInvariant() }
if ($origin -and (& $norm $origin) -eq (& $norm $RepoUrl)) {
    Write-Output "Unispace toolbar found at $ext ($origin)"
    exit 0
}
exit 1
