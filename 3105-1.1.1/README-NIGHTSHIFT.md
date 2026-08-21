# 3105 NIGHTSHIFT — custom UI fork

This fork keeps the original 3105 device/filesystem/patch/wallpaper engine intact and adds a dark cyberpunk presentation layer.

## Main changes
- `ThreeOneOSFive/views/DesignSystem.swift`
  - NIGHTSHIFT colors, panels, typography, and reusable cyber background.
- `ThreeOneOSFive/ContentView.swift`
  - Replaced the stock dashboard with a custom NIGHTSHIFT control deck.
- `ThreeOneOSFive/views/WallpaperLabView.swift`
  - Added the same visual shell and renamed the navigation title to `TENDIES // LAB`.

## Intentionally untouched
- `exploit/`
- `kexploit/`
- wallpaper installer/service logic
- patch/file operation logic
- bundle identifier and entitlements

This is a UI-focused fork. Build/signing and device testing still need to be performed in Xcode on a Mac with the appropriate Apple development setup.

The original project license and notices remain in this archive.
