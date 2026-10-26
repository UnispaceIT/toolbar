# Intune custom detection script for the Unispace pyRevit toolbar.
# Upload this in the app's Detection rules; it is not part of the .intunewin package.
# Intune treats "exit 0 with output on STDOUT" as installed; anything else as not installed.

$ext = Join-Path $env:APPDATA 'pyRevit\Extensions\Unispace.extension'

if ((Test-Path (Join-Path $ext 'extension.json')) -and (Test-Path (Join-Path $ext '.git'))) {
    Write-Output "Unispace toolbar found at $ext"
    exit 0
}
exit 1
