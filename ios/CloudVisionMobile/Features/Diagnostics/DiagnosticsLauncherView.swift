import SwiftUI
import os.log

/// F4 entry-point sheet — presents the diagnostic options for a port and routes through the
/// confirmation gate into the in-flight/result flow.
///
/// Step model:
///   .launcher → user picks Cable Test or Interface Cycle (and Cycle method)
///   .confirm  → full-screen R10 confirmation gate
///   .inFlight → polling progression (F4.4)
///   .result   → terminal state (F4.5)
struct DiagnosticsLauncherView: View {
    let deviceId: String
    let interfaceName: String

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .launcher
    @State private var pendingKind: DiagnosticRunner.DiagnosticKind = .cableTest

    enum Step {
        case launcher
        case confirm(DiagnosticRunner.DiagnosticKind)
        case inFlight(DiagnosticRunner.DiagnosticKind)
        case completed(DiagnosticRunner.DiagnosticKind, ChangeControl)
        case failed(DiagnosticRunner.DiagnosticKind, String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                switch step {
                case .launcher:
                    launcherContent
                case .confirm(let kind):
                    DiagnosticConfirmationView(
                        deviceId: deviceId,
                        interfaceName: interfaceName,
                        kind: kind,
                        onCancel: {
                            DiagnosticTelemetry.recordConfirmationCancelled(kind: kind)
                            step = .launcher
                        },
                        onConfirm: {
                            DiagnosticTelemetry.recordConfirmationCommitted(kind: kind)
                            step = .inFlight(kind)
                        }
                    )
                case .inFlight(let kind):
                    DiagnosticInFlightView(
                        deviceId: deviceId,
                        interfaceName: interfaceName,
                        kind: kind,
                        onCompleted: { snapshot in step = .completed(kind, snapshot) },
                        onFailed: { reason in step = .failed(kind, reason) }
                    )
                case .completed(let kind, let snapshot):
                    DiagnosticResultView(
                        deviceId: deviceId,
                        interfaceName: interfaceName,
                        kind: kind,
                        changeControl: snapshot,
                        onDone: { dismiss() },
                        onRunAgain: { step = .launcher }
                    )
                case .failed(let kind, let reason):
                    DiagnosticFailedView(
                        kind: kind,
                        reason: reason,
                        onDismiss: { dismiss() },
                        onRetry: { step = .confirm(kind) }
                    )
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if case .launcher = step {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }.foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        switch step {
        case .launcher:                       return "Interface Diagnostics"
        case .confirm(let k):                 return "Confirm \(k.shortLabel)"
        case .inFlight(let k):                return "\(k.shortLabel) — running"
        case .completed(let k, _):            return "\(k.shortLabel) — results"
        case .failed(let k, _):               return "\(k.shortLabel) — failed"
        }
    }

    // MARK: - Launcher content

    private var launcherContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("On port")
                        .font(.caption)
                        .foregroundStyle(Brand.slate)
                    Text("\(interfaceName) · \(deviceId)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Brand.graphite)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                diagnosticCard(
                    icon: "cable.connector.horizontal",
                    title: "Cable Test",
                    subtitle: "TDR probe — measures per-pair length and fault distance",
                    onTap: { step = .confirm(.cableTest) }
                )

                interfaceCycleCard
            }
            .padding(.bottom, 100)
        }
    }

    private func diagnosticCard(icon: String, title: String, subtitle: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Brand.steel)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Brand.graphite)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Brand.slate)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.slate)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var interfaceCycleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 22))
                    .foregroundStyle(Brand.steel)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Interface Cycle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Brand.graphite)
                    Text("Take the port down and bring it back up — pick a method:")
                        .font(.system(size: 13))
                        .foregroundStyle(Brand.slate)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider().padding(.leading, 58)

            methodButton(
                title: "Administratively",
                subtitle: "shutdown / no shutdown",
                action: { step = .confirm(.interfaceCycleAdmin) }
            )

            Divider().padding(.leading, 58)

            methodButton(
                title: "Power over Ethernet",
                subtitle: "Disable PoE, then restore power",
                action: { step = .confirm(.interfaceCyclePoe) }
            )
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private func methodButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Spacer().frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Brand.graphite)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Brand.slate)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.slate)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Telemetry hooks

enum DiagnosticTelemetry {
    private static let log = Logger(subsystem: "com.gullickson.CloudVisionMobile", category: "diagnostic-telemetry")

    static func recordConfirmationCancelled(kind: DiagnosticRunner.DiagnosticKind) {
        log.info("CONFIRMATION_CANCELLED kind=\(kind.shortLabel, privacy: .public)")
    }

    static func recordConfirmationCommitted(kind: DiagnosticRunner.DiagnosticKind) {
        log.info("CONFIRMATION_COMMITTED kind=\(kind.shortLabel, privacy: .public)")
    }
}

extension DiagnosticRunner.DiagnosticKind {
    /// Short label for navigation titles and telemetry.
    var shortLabel: String {
        switch self {
        case .cableTest:           return "Cable Test"
        case .interfaceCycleAdmin: return "Admin Cycle"
        case .interfaceCyclePoe:   return "PoE Cycle"
        }
    }
}
