import SwiftUI

private enum OTAStatus: String {
    case blocked = "BLOCKED"
    case clear = "CLEAR"
    case unknown = "UNKNOWN"
}

private struct OTAProbeResult {
    let status: OTAStatus
    let details: [String]
    let checkedAt: Date
    let accessible: Bool
}

struct OTAControlView: View {
    @State private var result: OTAProbeResult?
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
                            VStack(alignment: .leading, spacing: 10) {
                                Text("WHAT THIS CHECKS")
                                    .font(AppTheme.monoFont)
                                    .tracking(1.4)
                                    .foregroundStyle(.secondary)

                                Text("NIGHTSHIFT only inspects OTA-related state that is exposed to the current process. It does not modify, delete, or restore system files.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Divider().overlay(AppTheme.panelBorder)

                                checkRow("OTA configuration", result?.status == .blocked ? "Potential block detected" : "Read-only probe")
                                checkRow("System changes", "NONE")
                                checkRow("Restore action", "DISABLED")
                            }
                        }

                        if let result {
                            CyberPanel {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("DIAGNOSTIC")
                                        .font(AppTheme.monoFont)
                                        .tracking(1.4)
                                        .foregroundStyle(.secondary)

                                    ForEach(result.details, id: \.self) { detail in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "chevron.right")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(AppTheme.accent)
                                            Text(detail)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Text("Checked \(result.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 4)
                                }
                            }
                        }

                        Button {
                            checkOTA()
                        } label: {
                            HStack {
                                if isChecking {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "waveform.path.ecg")
                                }
                                Text(isChecking ? "CHECKING…" : "CHECK OTA STATUS")
                                    .font(.headline.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(isChecking)
                    }
                    .padding(.horizontal, AppTheme.pageInset)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("OTA // DETECTOR")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("OTA CONTROL")
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
        case .blocked: return AppTheme.secondaryAccent
        case .clear: return AppTheme.accent
        case .unknown, nil: return .secondary
        }
    }

    private var statusIcon: String {
        switch result?.status {
        case .blocked: return "exclamationmark.triangle.fill"
        case .clear: return "checkmark.shield.fill"
        case .unknown, nil: return "questionmark"
        }
    }

    private var statusSubtitle: String {
        switch result?.status {
        case .blocked:
            return "A potentially modified OTA configuration was detected."
        case .clear:
            return "No known OTA block signature was detected."
        case .unknown:
            return "Run a read-only diagnostic."
        }
    }

    private func checkRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func checkOTA() {
        guard !isChecking else { return }
        isChecking = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Deliberately conservative: 3105's process may not be able to
            // read the protected OTA plist on every supported build.
            // We therefore report "unknown" unless an accessible probe can
            // establish a known state. No system mutation is performed.
            let details = [
                "iOS: \(AppInfo.osVersion) (\(AppInfo.osBuild))",
                "Read-only mode: ENABLED",
                "Protected OTA state: \(SystemOTAProbe.probeDescription)",
                "No files or preferences were changed."
            ]

            let probe = OTAProbeResult(
                status: .unknown,
                details: details,
                checkedAt: Date(),
                accessible: SystemOTAProbe.isAccessible
            )

            DispatchQueue.main.async {
                result = probe
                isChecking = false
            }
        }
    }
}

private enum SystemOTAProbe {
    // We intentionally do not attempt to bypass iOS sandbox protections.
    // This path is used only as an accessibility probe.
    static let probePath = "/var/mobile/Library/Preferences/com.apple.MobileAsset.plist"

    static var isAccessible: Bool {
        FileManager.default.isReadableFile(atPath: probePath)
    }

    static var probeDescription: String {
        if isAccessible {
            return "OTA preference path is readable; signature decoding is not enabled in this build."
        }
        return "OTA preference path is protected/unreadable from this process."
    }
}
