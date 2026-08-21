# NIGHTSHIFT FINAL — Build Ready

This package includes the existing Cleaner plus the Thermal and OTA read-only views.

Project-file fix: ThermalControlView.swift and OTAControlView.swift are explicitly registered in the Xcode project file and the main Sources build phase.

The Thermal/OTA features are read-only. They must report Unknown when protected system state cannot be verified from the app's available privileges; they do not claim access to protected files merely from a known path.

The Cleaner keeps its existing scoped cache targets rather than deleting the entire application container.

IPA signing/building still requires a compatible iOS build environment or a legitimate build service.
