# Uninstaller Lookup GUI — Design

**Date:** 2026-06-17
**Status:** Approved
**Source:** Rewrite of `Get-Uninstaller.psm1` into a XAML/WPF GUI.

## Purpose

A standalone, view-only desktop tool for packagers that searches the Windows
registry for installed software and displays all matching uninstall entries in a
clean, scrollable list. Replaces the console-only `Get-Uninstaller` function with
a visual experience that scales gracefully from 1 to 20+ results.

## Goals

- Search installed software by (partial) name.
- Show every matching entry with full uninstall metadata.
- Scale visually from a single result to 20+ results via scrolling.
- Be self-contained and dependency-free so it can later be wrapped into an `.exe`.

## Non-Goals (YAGNI)

- No copying fields to clipboard (view only).
- No triggering/running uninstalls from the GUI.
- No module/importable function — this is a run-and-go tool.
- No async/background search threading.

## Delivery Format

A **single self-contained `Show-UninstallerGui.ps1`**:

- XAML defined inline as a here-string.
- WPF loaded via `Add-Type -AssemblyName PresentationFramework`.
- Registry-search logic kept as an internal `Get-Uninstaller` helper, refactored
  to **return objects** (not `Write-Host`), so the GUI consumes its output.
- **No external file dependencies** (no separate `.xaml`, no module import) — this
  keeps it reliable when wrapped into an `.exe` later.

## Architecture

```
Show-UninstallerGui.ps1
├── Add-Type PresentationFramework / PresentationCore / WindowsBase
├── function Get-Uninstaller   # internal helper, returns PSCustomObjects
├── $xaml here-string          # window definition + styles
├── Load window + find named controls
├── Event handlers (Search click, Enter key)
└── $window.ShowDialog()
```

### `Get-Uninstaller` helper (internal)

Refactored from the original. Searches three registry paths:

- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*`
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`
- `HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*`

Filters where `DisplayName` **or** `PSChildName` matches `*$Name*`. Returns
objects sorted by `DisplayName` with these properties:

`DisplayName, DisplayVersion, UninstallString, QuietUninstallString,
InstallLocation, InstallSource, InstallDate, Scope`

- `Scope` is a derived, human label for which hive the entry came from:
  `HKCU`, `HKLM (64-bit)`, or `HKLM (32-bit)` — determined from the entry's
  `PSPath`/`PSParentPath`.
- Uses `-ErrorAction SilentlyContinue` so an unreadable key never crashes.

## Window Layout (top → bottom)

1. **Header bar** — accent-colored band with title "Uninstaller Lookup" and a
   short subtitle.
2. **Search row** — a `TextBox` (placeholder "Search installed software…") and a
   **Search** button. Pressing **Enter** in the box also triggers search.
3. **Status line** — small muted text: `23 result(s) for "office"` /
   `No results for "office"` / `Enter a search term`.
4. **Results area** — a `ScrollViewer` wrapping an `ItemsControl` of expandable
   cards. This is the element that scales from 1 to 20+ results.

### Result card (an `Expander` styled as a card)

- **Collapsed header:** `DisplayName` (bold, left) + `DisplayVersion` (muted,
  right) + chevron.
- **Expanded body:** labelled rows for
  `UninstallString`, `QuietUninstallString`, `InstallLocation`, `InstallSource`,
  `InstallDate`, `Scope`.
- Empty/missing fields render as a muted `—` so layout stays consistent.
- Long strings (e.g. `UninstallString`) wrap rather than clip.

## Styling

Modern **light** theme:

- App background: `#F3F4F6` (light gray).
- Cards: white, rounded corners (~8px), subtle drop shadow.
- Accent: `#2563EB` (blue) — header band and Search button.
- Hover highlight on card headers.
- Muted text: `#6B7280` for secondary values and `—` placeholders.
- System default font (Segoe UI on Windows).

## Data Flow

```
User types name → click Search / press Enter
  → trim input
    → empty?  → status "Enter a search term", clear results
    → else    → Get-Uninstaller -Name <input>
                  → results? → bind to ItemsControl, status "N result(s)…"
                  → none?    → clear list, status "No results for …"
```

Search is **synchronous**. For the small registry dataset this is effectively
instant; accepting a possible sub-second freeze avoids runspace/threading
complexity and keeps exe-wrapping reliable.

## Error Handling

- Empty/whitespace query → no registry call; status prompts for a term.
- Registry read errors → silently ignored per-key (`SilentlyContinue`).
- No matches → friendly message in the results area, not an empty void.
- The whole search handler is wrapped so an unexpected error sets a status
  message instead of tearing down the window.

## Testing

WPF runs on **Windows only**; development here is on macOS. Therefore:

- **Local (macOS):** validate PowerShell syntax and XAML well-formedness
  (parse the here-string as XML).
- **Manual smoke test (Windows) — checklist:**
  1. Launch script → window opens, theme renders.
  2. Search a common term (e.g. `microsoft`) → multiple cards appear, scrollable.
  3. Search a unique term → exactly one card; layout still looks right.
  4. Search gibberish → "No results" message.
  5. Empty search → "Enter a search term", no crash.
  6. Expand/collapse cards → detail fields show; empty fields show `—`.
  7. Long `UninstallString` wraps and is fully readable.
  8. Resize window → results area grows/scrolls correctly.

## File Changes

- **Add:** `Show-UninstallerGui.ps1` (the new tool).
- **Delete:** `Get-Uninstaller.psm1` — superseded by the GUI.
