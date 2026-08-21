# NIGHTSHIFT v0.4 — OTA Detector

Adds a read-only `OTA // DETECTOR` screen.

Safety scope:
- Does not modify OTA state.
- Does not delete files.
- Does not attempt to bypass iOS sandbox protections.
- Reports UNKNOWN when protected OTA state is not readable.
- Intended as a diagnostic UI until a version-appropriate restore mechanism is verified.

This release is deliberately not an OTA remover/restorer.
