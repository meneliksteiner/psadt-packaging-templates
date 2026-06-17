# Tools

Helper utilities used while packaging applications for the
[PSAppDeployToolkit](https://psappdeploytoolkit.com/) templates in this
repository. These are **packaging-time aids**, not part of any deployment
package — nothing here ships inside `Invoke-AppDeployToolkit.ps1`. They live
here so every packager works from the same set of tools.

All three are Windows-only.

---

## Contents

| Tool | What it's for |
| --- | --- |
| [`UninstallFinder/`](#uninstallfinder) | Find an installed app's uninstall string / metadata |
| [`ProcessExplorer/`](#processexplorer) | Identify processes & executables to close during install |
| [`IcoFXPortable/`](#icofxportable) | Create and edit the app icons used in Intune |

---

## UninstallFinder

A self-contained WPF GUI for searching installed software and reading its
uninstall information straight from the Windows registry. Use it to grab the
`UninstallString` / `QuietUninstallString`, install location, and registry
scope (HKLM 64-bit, HKLM 32-bit, or HKCU) when authoring the
uninstall/detection logic for a package.

- `UninstallFinder.ps1` — the source script. Run it directly to launch the
  window, or dot-source it to reuse its functions (`Get-Uninstaller`,
  `Select-UninstallerEntry`, …) in your own scripts/tests.
- `Uninstall Finder.exe` — a packaged build of the same script for quick use
  on machines without a script host configured.

```powershell
# From this folder
.\UninstallFinder\UninstallFinder.ps1
```

Type a (partial) product name, press **Search**, and expand any result card to
see its full uninstall metadata.

## ProcessExplorer

Sysinternals **Process Explorer** — an advanced task manager. While packaging,
use it to find the exact executable names of running processes that must be
closed during an install (the values you feed to PSADT's
`Show-ADTInstallationWelcome -CloseProcesses`).

- `procexp.exe` — launcher (picks the right architecture)
- `procexp64.exe` / `procexp64a.exe` — 64-bit (x64 / ARM64) builds
- `Eula.txt` — Sysinternals license

Microsoft tool; see its EULA before redistributing.

## IcoFXPortable

Portable build of **IcoFX**, an icon/image editor. Use it to produce and tweak
the app icon (`.png`) that goes in each package's `Icon/` folder and is shown
in the Intune company portal.

- `IcoFXPortable.exe` — portable launcher
- `help.html` — built-in documentation

---

> **Note:** `ProcessExplorer` and `IcoFXPortable` are third-party tools bundled
> here for convenience. They are governed by their own licenses — review those
> before redistribution.
