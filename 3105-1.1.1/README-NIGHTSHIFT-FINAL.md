# 3105 NIGHTSHIFT FINAL

Custom UI-focused fork of 3105.

## Included
- NIGHTSHIFT cyberpunk dashboard/theme
- TENDIES // LAB visual shell
- File/folder Info view with recursive folder size calculation
- Cleaner: app cache cleaning plus a narrowly allowlisted global cache cleaner
- Global cache Analyze/Clean result reporting
- OTA // DETECTOR (read-only; no OTA mutation)
- Existing 3105 filesystem/patch/wallpaper/exploit logic preserved as much as possible

## Cleaner safety boundary
The added global cleaner targets only:
`/var/mobile/Library/Caches`

It does NOT intentionally remove arbitrary `/var/mobile` data, databases,
preferences, logs, snapshots, or other system state.

The iOS Settings "System Data" number is broader than this cache directory,
so cleaning cache will not necessarily reduce the entire displayed number by
the same amount.

## OTA safety boundary
The OTA screen is diagnostic only. It does not attempt to restore or remove
Nugget OTA tweaks on iOS 26.3.1 because a version-appropriate restore mechanism
has not been verified.

## Build
This archive is source code, not a precompiled IPA. It must be compiled with
a compatible Xcode/macOS environment before packaging/signing.

## Thermal Control
Adds `THERMAL // CONTROL` as a read-only detector for
`/var/db/com.apple.xpc.launchd/disabled.plist`.

It checks the `com.apple.thermalmonitord` entry and reports:
- DISABLED when the entry is truthy/YES
- ENABLED when the entry is absent or false
- UNKNOWN when the protected plist cannot be read

It never writes to or deletes the plist.

## Thermal detector access model
The thermal detector now explicitly checks 3105's existing
`KernelExploit.hasSandboxAccess()` state before reading the protected
`disabled.plist`. On iOS 26+, 3105's own exploit path requires a sandbox escape
for outside-container filesystem access. The detector remains read-only.
