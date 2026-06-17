# PSAppDeployToolkit – Intune Packaging Templates

A standardized folder structure for packaging applications with the
[PSAppDeployToolkit](https://psappdeploytoolkit.com/) (PSADT) and deploying them
through Microsoft Intune as Win32 apps.

The whole point of this repository is **one predictable layout for every
application**, so that any packager (or automation script) can find, build, and
version a package without guessing.

---

## Folder structure

```
AppVendor_AppName_AppType_AppArch/
└── AppVersion/
    └── AppRevision/        (001, 002, 003 …)
        ├── Icon/           # App icon (.png) used in the Intune company portal
        └── Script/
            ├── Invoke-AppDeployToolkit.ps1   # Main deployment script
            ├── Config/                       # PSADT config.psd1
            ├── Strings/                      # Localized UI strings
            ├── Files/                        # Installer payload (.exe/.msi/etc.)
            ├── SupportFiles/                 # Extra files referenced at runtime
            ├── Assets/                       # Banners / logos for the PSADT UI
            └── PSAppDeployToolkit/           # The toolkit module itself
```

The identity of a package is fully described by three nested levels:

```
AppVendor_AppName_AppType_AppArch  /  AppVersion  /  AppRevision
└──────────── what it is ────────┘    └ which ┘     └ which build ┘
```

### Level 1 – `AppVendor_AppName_AppType_AppArch`

The unique identity of the *product*. Four fields, separated by underscores:

| Field       | Meaning                                          | Examples                            |
| ----------- | ------------------------------------------------ | ----------------------------------- |
| `AppVendor` | Publisher / manufacturer                         | `Mozilla`, `Microsoft`              |
| `AppName`   | Product name (no spaces)                         | `Firefox`, `DotNetDesktopRuntime8`  |
| `AppType`   | Package **variant / flavor** of the same product | `Default`, `VDI`, `FatClient`, `Server` |
| `AppArch`   | Target architecture                              | `x64`, `x86`, `ARM64`, `Neutral`    |

`AppType` distinguishes **special-purpose builds of the same software** that
must be packaged differently for different target estates. The product and
version are identical; what changes is an install-time argument, tag, group ID,
or configuration baked into the package.

Typical drivers:

- **VDI vs. physical (Fat Client)** — a non-persistent VDI image needs a
  different agent provisioning mode than a permanent desktop.
- **Per-tenant / per-business-unit tags** — security agents are stamped with a
  customer ID, sensor group, or activation token at install time.
- **Configuration profiles** — e.g. a "kiosk" build vs. a "standard" build.

Examples where this matters: **CrowdStrike Falcon** (different sensor grouping
tags / `--VDI` provisioning for non-persistent images) and **Qualys Cloud
Agent** (different `ActivationId` / `CustomerId` or VDI flag per estate). Use
`Default` when no variant is needed.

### Level 2 – `AppVersion`

The exact product version this package installs, e.g. `126.0.1` or `8.0.6`.
Each version gets its own folder so older versions stay intact and auditable.

### Level 3 – `AppRevision`

A zero-padded build counter (`001`, `002`, …) for the *same* app version. Use a
new revision when the version is unchanged but the **package** changes — a fixed
detection rule, a tweaked install switch, an updated icon. The installed product
is identical; only your packaging improved.

---

## Why this structure makes sense

**Architecture is part of the identity, not an afterthought.**
Because `AppArch` lives in the top-level folder name, x86 and x64 builds of the
same product are simply *two different products*. There is no special case, no
suffix hack, no "which one is this again?" — they sit side by side as peers.

**Variants live side by side, not as forks.**
Because `AppType` is part of the identity, a VDI build and a Fat-Client build of
the same agent are two peer packages — not a branch, a rename, or a commented-out
switch you have to remember to flip. Each gets its own detection rule and Intune
assignment, so the VDI group and the desktop group can never receive the wrong
provisioning tag.

**No collisions between similar software.**
Two packages that share a name but differ in vendor, variant, or architecture
never overwrite or shadow each other, because all four distinguishing fields are
baked into the folder name. The path *is* the uniqueness constraint.

**Versions never clobber each other.**
A new release is a new `AppVersion` folder. You can ship `126.0.1`, keep
`125.0.3` for rollback, and diff the two without any branching or renaming.

**Repackaging is cheap and traceable.**
Re-packaging the same version (new detection logic, new switches) is just a new
`AppRevision`. The version history stays clean and the *why did this change?*
question is answered by the revision number.

**Sortable, scriptable, and self-documenting.**
The path alone tells you the vendor, app, installer type, architecture, version,
and build. Automation can enumerate, build `.intunewin` files, and assign
detection rules purely from the folder name — no metadata lookup required.

**Stable for the whole lifecycle.**
The structure is identical whether you have 1 app or 1,000. Onboarding a new
packager means teaching one rule: `Vendor_Name_Type_Arch / Version / Revision`.

---

## Examples

### Mozilla Firefox (64-bit)

```
Mozilla_Firefox_Default_x64/
└── 126.0.1/
    └── 001/
        ├── Icon/
        │   └── Firefox.png
        └── Script/
            ├── Invoke-AppDeployToolkit.ps1
            └── Files/
                └── Firefox Setup 126.0.1.exe
```

### Microsoft .NET Desktop Runtime 8 & 9 (x86 *and* x64)

Two things vary independently here: the **major version** (8 vs. 9, which are
separate side-by-side runtimes, not upgrades of each other) and the
**architecture**. Both are part of the top-level identity, so all four builds are
completely independent packages — no edge cases, no shared folders:

```
Microsoft_DotNetDesktopRuntime8_Default_x86/
└── 8.0.6/
    └── 001/
        └── Script/
            └── Files/
                └── windowsdesktop-runtime-8.0.6-win-x86.exe

Microsoft_DotNetDesktopRuntime8_Default_x64/
└── 8.0.6/
    └── 001/
        └── Script/
            └── Files/
                └── windowsdesktop-runtime-8.0.6-win-x64.exe

Microsoft_DotNetDesktopRuntime9_Default_x86/
└── 9.0.0/
    └── 001/
        └── Script/
            └── Files/
                └── windowsdesktop-runtime-9.0.0-win-x86.exe

Microsoft_DotNetDesktopRuntime9_Default_x64/
└── 9.0.0/
    └── 001/
        └── Script/
            └── Files/
                └── windowsdesktop-runtime-9.0.0-win-x64.exe
```

The major version lives in `AppName` (`DotNetDesktopRuntime8` vs.
`DotNetDesktopRuntime9`) because .NET runtimes install side by side — a machine
can hold both at once. That keeps the `AppVersion` folder for the *minor/patch*
releases within a major (`9.0.0`, `9.0.1`, …), so each runtime line is versioned
and assigned in Intune on its own schedule, yet every build is instantly
recognizable from its path.

### CrowdStrike Windows Sensor (VDI *and* Fat Client — different equipment)

Same vendor, same product, same version — but the two estates run on different
equipment with different needs. The VDI image is non-persistent, so the sensor
must be provisioned with `VDI=1` (no Agent ID baked into the gold image), while
physical Fat Clients get a standard persistent install. `AppType` keeps them as
two clean, independently assignable packages:

```
CrowdStrike_WindowsSensor_VDI_x64/
└── 7.16.0/
    └── 001/
        └── Script/
            ├── Invoke-AppDeployToolkit.ps1   # installs with VDI=1 / provisioning tag
            └── Files/
                └── WindowsSensor.exe

CrowdStrike_WindowsSensor_FatClient_x64/
└── 7.16.0/
    └── 001/
        └── Script/
            ├── Invoke-AppDeployToolkit.ps1   # standard persistent install
            └── Files/
                └── WindowsSensor.exe
```

Assign `…_VDI_…` to your non-persistent VDI device group and `…_FatClient_…` to
physical desktops. The wrong equipment can never get the wrong provisioning mode,
because they are different packages with different detection rules. The same
pattern applies to **Qualys Cloud Agent** when the `ActivationId`/`CustomerId`
or VDI flag differs between estates.
