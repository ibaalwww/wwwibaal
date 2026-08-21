import SwiftUI

private enum ThermalStatus: String {
    case disabled = "DISABLED"
    case enabled = "ENABLED"
    case unknown = "UNKNOWN"
}

private struct ThermalProbeResult {
    let status: ThermalStatus
    let detail: String
    let checkedAt: Date
}

struct ThermalControlView: View {
    @State private var result: ThermalProbeResult?
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            ZStack {
                CyberBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        statusCard

                        CyberPanel {
                            VStack(alignment: .leading, spacing: 11) {
                                Text("READ-ONLY DETECTOR")
                                    .font(AppTheme.monoFont)
                                    .tracking(1.4)
                                    .foregroundStyle(.secondary)

                                Text("Checks whether com.apple.thermalmonitord is present in disabled.plist. NIGHTSHIFT does not add, remove, or modify the entry.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Divider().overlay(AppTheme.panelBorder)

                                checkRow("Target", "com.apple.thermalmonitord")
                                checkRow("File", "/var/db/com.apple.xpc.launchd/disabled.plist")
                                checkRow("Mode", "READ ONLY")
                            }
                        }

                        Button {
                            checkThermalStatus()
                        } label: {
                            HStack {
                                if isChecking {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "thermometer.medium")
                                }
                                Text(isChecking ? "CHECKING…" : "CHECK STATUS")
                                    .font(.headline.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(isChecking)

                        if let result {
                            CyberPanel {
                                VStack(alignment: .leading, spacing: 9) {
                                    Text("DIAGNOSTIC")
                                        .font(AppTheme.monoFont)
                                        .tracking(1.4)
                                        .foregroundStyle(.secondary)

                                    Text(result.detail)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)

                                    Text("Checked \(result.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.pageInset)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("THERMAL // CONTROL")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("THERMAL CONTROL")
                .font(AppTheme.titleFont)
            Text("READ-ONLY SYSTEM DIAGNOSTIC")
                .font(AppTheme.monoFont)
                .tracking(1.5)
                .foregroundStyle(AppTheme.accent)
        }
    }

    private var statusCard: some View {
        CyberPanel {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.14))
                    Image(systemName: statusIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(statusColor)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result?.status.rawValue ?? "NOT CHECKED")
                        .font(.title3.weight(.black))
                        .foregroundStyle(statusColor)

                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var statusColor: Color {
        switch result?.status {
        case .disabled: return AppTheme.secondaryAccent
        case .enabled: return AppTheme.accent
        case .unknown, nil: return .secondary
        }
    }

    private var statusIcon: String {
        switch result?.status {
        case .disabled: return "thermometer.high"
        case .enabled: return "checkmark.shield.fill"
        case .unknown, nil: return "questionmark"
        }
    }

    private var statusSubtitle: String {
        switch result?.status {
        case .disabled:
            return "thermalmonitord is listed as disabled."
        case .enabled:
            return "thermalmonitord is not listed as disabled."
        case .unknown, nil:
            return "Run a read-only diagnostic."
        }
    }

    private func checkRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.trailing)
        }
    }

    private func checkThermalStatus() {
        guard !isChecking else { return }
        isChecking = true

        DispatchQueue.global(qos: .userInitiated).async {
            let probe = ThermalMonitorProbe.readStatus()

            DispatchQueue.main.async {
                result = ThermalProbeResult(
                    status: probe.status,
                    detail: probe.detail,
                    checkedAt: Date()
                )
                isChecking = false
            }
        }
    }
}

private enum ThermalMonitorProbe {
    private static let disabledPlistPath =
        "/var/db/com.apple.xpc.launchd/disabled.plist"

    static func readStatus() -> (status: ThermalStatus, detail: String) {
        // 3105 already has a kernel/sandbox-escape implementation for iOS 26+.
        // Do not pretend the path is readable until that access is active.
        guard KernelExploit.hasSandboxAccess() else {
            return (
                .unknown,
                "3105 sandbox access is not active. Run the existing 3105 exploit/access stage first."
            )
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: disabledPlistPath) else {
            return (
                .unknown,
                "disabled.plist was not found at the expected path."
            )
        }

        guard fm.isReadableFile(atPath: disabledPlistPath) else {
            return (
                .unknown,
                "Sandbox access is active, but disabled.plist is still not readable."
            )
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: disabledPlistPath))
            let object = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )

            guard let plist = object as? [String: Any] else {
                return (.unknown, "disabled.plist was read but is not a dictionary plist.")
            }

            if let value = plist["com.apple.thermalmonitord"] as? Bool {
                return value
                    ? (.disabled, "com.apple.thermalmonitord = YES")
                    : (.enabled, "com.apple.thermalmonitord = NO")
            }

            if let value = plist["com.apple.thermalmonitord"] as? String {
                let normalized = value.lowercased()
                if ["yes", "true", "1"].contains(normalized) {
                    return (.disabled, "com.apple.thermalmonitord is set to a truthy value.")
                }
                if ["no", "false", "0"].contains(normalized) {
                    return (.enabled, "com.apple.thermalmonitord is set to a false value.")
                }
            }

            return (
                .enabled,
                "com.apple.thermalmonitord is not present in disabled.plist."
            )
        } catch {
            return (.unknown, "Unable to decode disabled.plist: \(error.localizedDescription)")
        }
    }
}
