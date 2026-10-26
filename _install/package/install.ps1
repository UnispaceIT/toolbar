<#
.SYNOPSIS
    Installs (or repairs/updates) the Unispace pyRevit toolbar for the current user.

.DESCRIPTION
    Clones https://github.com/UnispaceIT/toolbar (branch main) into the user's
    pyRevit Extensions folder, enables it, and turns on pyRevit's auto-update so the
    toolbar pulls the latest main every time Revit starts.

    Safe to run repeatedly: an existing install is updated rather than re-cloned.
    Runs in user context; no admin rights needed. Requires pyRevit.

    Exit codes: 0 = success, 1 = failure (details in %LOCALAPPDATA%\Unispace\Logs).

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
.EXAMPLE
    .\install.ps1 -WhatIf     # log what would happen without changing anything
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

. (Join-Path $PSScriptRoot 'common.ps1')

function Install-Toolbar {
    Write-Log "=== Unispace toolbar install (user: $env:USERNAME) ==="

    $pyrevit = Find-PyRevit
    if (-not $pyrevit) {
        Write-Log 'pyRevit is not installed (pyrevit.exe not found). Install pyRevit from Company Portal first.' 'ERROR'
        return 1
    }
    Write-Log "Using pyRevit CLI: $pyrevit"

    $registered = Get-RegisteredExtensionPath -Exe $pyrevit
    if ($registered -and -not (Test-SamePath $registered $ManagedPath)) {
        # Someone is running the toolbar from their own clone (e.g. a developer).
        # 'pyrevit extensions update' force-resets, so leave it completely alone.
        Write-Log "$ExtensionName is already installed from '$registered', which this installer does not manage. Leaving it untouched." 'WARN'
        return 0
    }

    if ((Test-Path $ManagedPath) -and -not (Test-Path (Join-Path $ManagedPath '.git'))) {
        Write-Log "'$ManagedPath' exists but is not a git clone; removing it so it can be re-cloned." 'WARN'
        if ($PSCmdlet.ShouldProcess($ManagedPath, 'Remove broken install')) {
            Remove-Item -Path $ManagedPath -Recurse -Force
        }
    }

    if (Test-Path (Join-Path $ManagedPath '.git')) {
        Write-Log "Existing install found at '$ManagedPath'; updating."
        if ($PSCmdlet.ShouldProcess($ManagedPath, 'Update toolbar from git')) {
            if (-not $registered) {
                # Folder is there but pyRevit forgot the search path (e.g. config was reset).
                Invoke-PyRevit $pyrevit @('extensions', 'paths', 'add', $ExtensionsRoot) | Out-Null
            }
            if (-not (Invoke-PyRevit $pyrevit @('extensions', 'update', $ExtensionName))) {
                # Not fatal: the existing copy still works and auto-update will retry at Revit startup.
                Write-Log 'Update failed (offline?). Keeping the existing copy.' 'WARN'
            }
        }
    }
    else {
        Write-Log "Cloning $RepoUrl ($Branch) to '$ManagedPath'."
        if ($PSCmdlet.ShouldProcess($ManagedPath, "Clone $RepoUrl")) {
            Invoke-PyRevit $pyrevit @('extend', 'ui', $ExtensionName, $RepoUrl, "--branch=$Branch") | Out-Null
            if (-not (Test-Path (Join-Path $ManagedPath 'extension.json'))) {
                Write-Log "Clone failed: '$ManagedPath\extension.json' not found. Check network access to github.com." 'ERROR'
                return 1
            }
        }
    }

    if ($PSCmdlet.ShouldProcess($ExtensionName, 'Enable extension')) {
        if (-not (Invoke-PyRevit $pyrevit @('extensions', 'enable', $ExtensionName))) {
            Write-Log "Could not enable $ExtensionName in pyRevit." 'ERROR'
            return 1
        }
    }

    if ($PSCmdlet.ShouldProcess('pyRevit', 'Enable auto-update at Revit startup')) {
        if (-not (Invoke-PyRevit $pyrevit @('configs', 'autoupdate', 'enable'))) {
            # Happens if IT has locked pyRevit's config read-only. The toolbar still works.
            Write-Log 'Could not enable pyRevit auto-update; users will need the pyRevit Update button to get new versions.' 'WARN'
        }
    }

    Write-Log 'Install complete. Restart Revit (or reload pyRevit) to see the toolbar.'
    return 0
}

try {
    $code = Install-Toolbar
}
catch {
    Write-Log "Unexpected error: $($_.Exception.Message)" 'ERROR'
    $code = 1
}
exit $code
