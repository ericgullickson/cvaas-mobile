import SwiftUI

/// Full-screen confirmation gate per CAP-4.4 / R10. Critical UX invariants:
///
/// 1. The Confirm button is at the bottom of the screen, deliberately far from where the
///    user just tapped on the launcher list. No system Alert with a default OK that can be
///    bonked through by muscle memory.
/// 2. The disruption window and exact action are restated in plain English.
/// 3. The ChangeControl audit-log behavior is disclosed (compliance with R12).
/// 4. Cancel is the visually-prominent option; Confirm is destructive-styled in red.
///
/// Tap counts on cancel-vs-confirm flow through `DiagnosticTelemetry` so OBJ-3's
/// "zero unintended outages" success metric (PRD §3b) has a measurement plan.
struct DiagnosticConfirmationView: View {
    let deviceId: String
    let interfaceName: String
    let kind: DiagnosticRunner.DiagnosticKind
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    disruptionBanner
                    actionSummary
                    auditNotice
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            actionBar
        }
    }

    // MARK: - Sections

    private var disruptionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 18, weight: .semibold))
                Text("This will disrupt service")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Brand.graphite)
            }
            Text("Running this test puts \(interfaceName) out of operation for up to **10 seconds**. Any device connected to this port — voice phones, security cameras, access points — will briefly lose link.")
                .font(.system(size: 14))
                .foregroundStyle(Brand.graphite)
                .lineSpacing(2)
        }
        .padding(16)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var actionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "ACTION")
            VStack(spacing: 0) {
                summaryRow(label: "Test", value: kind.displayName)
                Divider().padding(.leading, 16)
                summaryRow(label: "Device", value: deviceId, monospaced: true)
                Divider().padding(.leading, 16)
                summaryRow(label: "Interface", value: interfaceName, monospaced: true)
                Divider().padding(.leading, 16)
                summaryRow(label: "Disruption", value: "~10 seconds")
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var auditNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(Brand.steel)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text("Recorded in the audit log")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.graphite)
                Text("CloudVision records this action under your service-account identity and routes it through ChangeControl. Strict-mode tenants may require admin approval before the test runs.")
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.slate)
            }
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 10) {
            Button(action: onConfirm) {
                Text("Run \(kind.shortLabel)")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(Brand.steel)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            Color(.systemGroupedBackground)
                .overlay(alignment: .top) {
                    Rectangle().fill(Brand.mist.opacity(0.5)).frame(height: 0.5)
                }
        )
    }

    private func summaryRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Brand.slate)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: monospaced ? .monospaced : .default))
                .foregroundStyle(Brand.graphite)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
