# Unispace toolbar installer (Company Portal / Intune)

Installs the Unispace pyRevit toolbar for the signed-in user, without admin rights.

## How it works

- `install.ps1` uses the pyRevit CLI to clone this repo (`main`) into
  `%APPDATA%\pyRevit\Extensions\Unispace.extension`, enables it, and turns on
  pyRevit's **auto-update** setting.
- With auto-update on, pyRevit runs `git pull` on the toolbar every time Revit
  starts. **Anything merged to `main` reaches users on their next Revit launch**;
  the installer never needs rebuilding for toolbar changes.
- Re-running the installer is safe. An existing install is updated, a broken one is
  re-cloned, and a copy installed from anywhere else (e.g. a developer's own clone)
  is left untouched.
- **Moving off the old repo.** The toolbar used to live at `Unispace365/toolbar`,
  which Unispace no longer controls. Installs that still pull from it are treated as
  not installed by `detect.ps1`, so Intune runs the installer, which removes them and
  re-clones from `UnispaceIT/toolbar`. If Revit is open and holding files, the
  installer fails with a log message and Intune retries later.
- `uninstall.ps1` removes the clone. pyRevit and its settings are left as-is.
- Both scripts log to `%LOCALAPPDATA%\Unispace\Logs\toolbar-install.log` and exit
  non-zero on failure, so Intune reports failures correctly.

> Auto-update skips silently if pyRevit's connectivity check fails: before updating,
> pyRevit opens a TCP connection to `8.8.8.8:53`. If the network blocks that, users
> can still update from the pyRevit tab's **Update** button.

## Files

| File | Purpose |
| --- | --- |
| `package/install.ps1` | Install / update. Supports `-WhatIf` for a dry run. |
| `package/uninstall.ps1` | Uninstall. Supports `-WhatIf`. |
| `package/common.ps1` | Shared settings (extension name, repo URL, branch) and helpers. |
| `detect.ps1` | Intune detection script. Uploaded separately, not packaged. |
| `Install Unispace Toolbar.cmd` | Double-click installer for testers. Not needed by Intune. |

## Intune setup (for IT)

1. Package the `package` folder with the
   [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool):

   ```bat
   IntuneWinAppUtil.exe -c _install\package -s install.ps1 -o out
   ```

2. Create a **Windows app (Win32)** from `out\install.intunewin`:

   | Setting | Value |
   | --- | --- |
   | Install command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1` |
   | Uninstall command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1` |
   | Install behavior | **User** |
   | Device restart behavior | No specific action |
   | Return codes | Defaults (0 = success; the scripts return 1 on failure) |
   | Detection rules | Custom script → `detect.ps1`, run as 32-bit: No, enforce signature check: No |
   | Dependencies | The **pyRevit** Company Portal app, *Automatically install*: Yes |

   Use the `detect.ps1` script rule, not a simple "file exists" rule. A file rule
   can't tell an old install (pulling from `Unispace365/toolbar`) from a new one, so
   old installs would never be replaced.

3. Replace the old "Unispace Toolbar Installer v2.exe" app. Its uninstaller never
   worked, so supersede it **without** "Uninstall previous version". The new
   installer adopts existing installs and turns on auto-update for them.

## Changing what gets installed

Edit the variables at the top of `package/common.ps1` (`$RepoUrl`, `$Branch`, ...),
then have IT repackage and upload a new version. Only needed for changes to the
install process itself, not for toolbar changes.

## Testing locally

For a non-technical tester: zip the `_install` folder, share it through OneDrive or
Teams (email often strips `.cmd`/`.ps1` attachments), and have them unzip it and
double-click **Install Unispace Toolbar.cmd**. Windows may show a "Windows protected
your PC" warning for a downloaded file: *More info* → *Run anyway*. On failure the
log opens in Notepad for them to send back.

From a terminal:

```powershell
.\package\install.ps1 -WhatIf     # shows what would happen, changes nothing
.\package\install.ps1             # real install for the current user
.\detect.ps1; $LASTEXITCODE       # 0 + output = detected
.\package\uninstall.ps1
```

On a machine where the toolbar is loaded from a development clone, the installer
logs a warning and does nothing.
