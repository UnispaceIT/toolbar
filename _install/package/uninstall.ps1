<#
.SYNOPSIS
    Removes the Unispace pyRevit toolbar for the current user.

.DESCRIPTION
    Deletes the clone this installer manages (%APPDATA%\pyRevit\Extensions\Unispace.extension).
    A copy installed anywhere else is left alone. pyRevit itself and its settings
    (including auto-update) are not changed.

    Exit codes: 0 = success, 1 = failure (details in %LOCALAPPDATA%\Unispace\Logs).

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot 'common.ps1')

function Uninstall-Toolbar {
    Write-Log "=== Unispace toolbar uninstall (user: $env:USERNAME) ==="

    if (-not (Test-Path $ManagedPath)) {
        Write-Log "Nothing to remove at '$ManagedPath'."
        return 0
    }

    $pyrevit = Find-PyRevit
    if ($pyrevit -and (Test-SamePath (Get-RegisteredExtensionPath -Exe $pyrevit) $ManagedPath)) {
        if ($PSCmdlet.ShouldProcess($ManagedPath, 'pyrevit extensions delete')) {
            Invoke-PyRevit $pyrevit @('extensions', 'delete', $ExtensionName) | Out-Null
        }
    }

    # Covers pyRevit being gone already, or the CLI leaving files behind.
    if ((Test-Path $ManagedPath) -and $PSCmdlet.ShouldProcess($ManagedPath, 'Remove folder')) {
        Remove-Item -Path $ManagedPath -Recurse -Force
    }

    if (Test-Path $ManagedPath) {
        if ($WhatIfPreference) { return 0 }
        Write-Log "Could not fully remove '$ManagedPath' (files in use by Revit?). Close Revit and retry." 'ERROR'
        return 1
    }

    Write-Log 'Uninstall complete.'
    return 0
}

try {
    $code = Uninstall-Toolbar
}
catch {
    Write-Log "Unexpected error: $($_.Exception.Message)" 'ERROR'
    $code = 1
}
exit $code
