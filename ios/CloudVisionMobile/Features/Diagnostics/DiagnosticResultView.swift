import SwiftUI

/// Terminal-state view shown after a diagnostic completes. Renders Cable-Test per-pair
/// results (CAP-4.2) or Interface-Cycle operational outcome (CAP-4.3), plus the
/// ChangeControl audit summary.
///
/// Cable Test results come from NetDB via `CableTestResultService`. Interface Cycle's
/// result is reconstructed from the ChangeControl envelope — no dedicated NetDB tree
/// (PRD §5d note + F4.1.c finding).
struct DiagnosticResultView: View {
    let deviceId: String
    let interfaceName: String
    let kind: DiagnosticRunner.DiagnosticKind
    let changeControl: ChangeControl
    let onDone: () -> Void
    let onRunAgain: () -> Void

    @EnvironmentObject private var auth: AuthStore
    @State private var cableResult: CableTestResult?
    @State private var cableLoadState: CableLoadState = .idle

    enum CableLoadState {
        case idle, loading, loaded
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                completionBanner
                if kind == .cableTest {
                    cableTestSection
                } else {
                    interfaceCycleSection
                }
                auditSection
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .task(id: changeControl.key.id) {
            if kind == .cableTest { await loadCableResult() }
        }
    }

    // MARK: - Completion banner

    private var completionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Diagnostic complete")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Brand.graphite)
                Text("\(kind.displayName) ran successfully on \(interfaceName).")
                    .font(.system(size: 13))
                    .foregroundStyle(Brand.slate)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Cable test section

    @ViewBuilder
    private var cableTestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "CABLE")
            cableSummaryCard
        }
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "PAIRS")
            pairsCard
        }
    }

    private var cableSummaryCard: some View {
        VStack(spacing: 0) {
            switch cableLoadState {
            case .idle, .loading:
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 24)
            case .failure(let msg):
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16).padding(.vertical, 14)
            case .loaded:
                summaryRow(label: "Whole cable", value: humanCableState(cableResult?.cableState), badge: cableBadgeIntent(cableResult?.cableState))
                Divider().padding(.leading, 16)
                summaryRow(label: "Length accuracy",
                           value: cableResult?.lengthAccuracyMeters.map { "±\($0) m" } ?? "—",
                           monospaced: true)
                Divider().padding(.leading, 16)
                summaryRow(label: "Total runs",
                           value: cableResult?.cableTestRuns.map { "\($0)" } ?? "—",
                           monospaced: true)
            }
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var pairsCard: some View {
        VStack(spacing: 0) {
            if let pairs = cableResult?.pairs, !pairs.isEmpty {
                ForEach(Array(pairs.enumerated()), id: \.element.label) { index, pair in
                    pairRow(pair: pair)
                    if index < pairs.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            } else if case .loaded = cableLoadState {
                Text("No per-pair data reported. On a healthy short cable, the device often returns 0 m on all pairs.")
                    .font(.system(size: 13))
                    .foregroundStyle(Brand.slate)
                    .padding(16)
            } else {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 24)
            }
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func pairRow(pair: CableTestResult.PairResult) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(pairStateColor(pair.pairState))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pair \(pair.label)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Brand.graphite)
                Text("Pin \(pair.pinPair)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Brand.slate)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(pair.lengthMeters.map { "\($0) m" } ?? "—")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Brand.graphite)
                Text(humanPairState(pair.pairState))
                    .font(.system(size: 11))
                    .foregroundStyle(pairStateColor(pair.pairState))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Interface cycle section

    private var interfaceCycleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "OUTCOME")
            VStack(spacing: 0) {
                summaryRow(label: "Cycle method", value: cycleMethodLabel)
                Divider().padding(.leading, 16)
                summaryRow(label: "Result", value: "Port came back up", badge: .success)
                Divider().padding(.leading, 16)
                summaryRow(label: "Total disruption",
                           value: cycleDurationLabel,
                           monospaced: true)
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Brand.steel)
                Text("CVaaS records the operational-state transitions for the cycle window — viewable in the CloudVision web UI under Interface Diagnostics.")
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.slate)
            }
            .padding(.horizontal, 4)
        }
    }

    private var cycleMethodLabel: String {
        switch kind {
        case .interfaceCycleAdmin: return "Admin shut / no-shut"
        case .interfaceCyclePoe:   return "PoE off / on"
        default:                   return "—"
        }
    }

    private var cycleDurationLabel: String {
        guard let stages = changeControl.change?.stages?.values,
              let stage = stages.values.first,
              let start = stage.startTime,
              let end = stage.endTime,
              let s = ISO8601Date.parse(start),
              let e = ISO8601Date.parse(end) else {
            return "—"
        }
        let seconds = e.timeIntervalSince(s)
        return String(format: "%.1f s", seconds)
    }

    // MARK: - Audit section

    private var auditSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "AUDIT")
            VStack(spacing: 0) {
                summaryRow(label: "Change Control", value: changeControl.key.id, monospaced: true)
                Divider().padding(.leading, 16)
                summaryRow(label: "Initiated by",
                           value: changeControl.change?.user ?? "—")
                Divider().padding(.leading, 16)
                summaryRow(label: "Approved by",
                           value: changeControl.approve?.user ?? "—")
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 8) {
            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Brand.navy, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Button(action: onRunAgain) {
                Text("Run another diagnostic")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
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

    // MARK: - Row builder

    enum BadgeIntent { case success, warning, danger, neutral }

    private func summaryRow(label: String, value: String, monospaced: Bool = false, badge: BadgeIntent? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Brand.slate)
            Spacer()
            if let badge {
                StatusPill(label: value, intent: badgeIntent(badge))
            } else {
                Text(value)
                    .font(.system(size: 14, weight: .medium, design: monospaced ? .monospaced : .default))
                    .foregroundStyle(Brand.graphite)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func badgeIntent(_ b: BadgeIntent) -> StatusPill.Intent {
        switch b {
        case .success: return .success
        case .warning: return .warning
        case .danger:  return .danger
        case .neutral: return .neutral
        }
    }

    // MARK: - Loading

    private func loadCableResult() async {
        guard let url = URL(string: auth.tenantURL) else {
            cableLoadState = .failure("Invalid tenant URL"); return
        }
        cableLoadState = .loading
        do {
            let client = try ConnectorClient(tenantURL: url, jwt: auth.jwt)
            let svc = CableTestResultService(client: client)
            // Brief settle delay — NetDB result write happens shortly after ChangeControl
            // status flips to COMPLETED.
            try? await Task.sleep(for: .seconds(2))
            cableResult = try await svc.fetch(deviceSerial: deviceId, interfaceName: interfaceName)
            await client.shutdown()
            cableLoadState = .loaded
        } catch {
            cableLoadState = .failure("Couldn't read result: \(error.localizedDescription)")
        }
    }

    // MARK: - Mapping helpers

    private func humanCableState(_ raw: String?) -> String {
        switch raw {
        case "cableStateOk":      return "OK"
        case "cableStateFault":   return "Fault"
        case "cableStateUnknown": return "Unknown"
        case .some(let s):        return s
        case nil:                 return "—"
        }
    }

    private func cableBadgeIntent(_ raw: String?) -> BadgeIntent? {
        switch raw {
        case "cableStateOk":     return .success
        case "cableStateFault":  return .danger
        case "cableStateUnknown": return .neutral
        default:                 return nil
        }
    }

    private func humanPairState(_ raw: String?) -> String {
        switch raw {
        case "pairStateOk":      return "OK"
        case "pairStateOpen":    return "Open"
        case "pairStateShort":   return "Short"
        case "pairStateUnknown": return "Unknown"
        case .some(let s):       return s
        case nil:                return "—"
        }
    }

    private func pairStateColor(_ raw: String?) -> Color {
        switch raw {
        case "pairStateOk":    return .green
        case "pairStateOpen",
             "pairStateShort": return .red
        default:               return Brand.slate
        }
    }
}

// MARK: - Failed-state view

struct DiagnosticFailedView: View {
    let kind: DiagnosticRunner.DiagnosticKind
    let reason: String
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            EmptyStateView(
                systemImage: "exclamationmark.triangle.fill",
                title: "\(kind.displayName) failed",
                message: reason
            )
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Close")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(Brand.graphite)
                }
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Brand.navy, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}
