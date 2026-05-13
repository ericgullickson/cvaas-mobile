import SwiftUI

/// In-flight diagnostic run UI per CAP-4.5. Drives `DiagnosticRunner` and renders its
/// progress events as a vertical stepper.
///
/// Backgrounding (tab-switch during run): a `.task` modifier keyed on the device+interface+kind
/// triple keeps the AsyncStream alive while this view is in the navigation stack. The runner's
/// `onTermination` cancels the underlying task if the user dismisses the sheet — so we don't
/// leak network work, but we also don't try to survive sheet teardown (that's pilot-data, not
/// MVP-table-stakes).
struct DiagnosticInFlightView: View {
    let deviceId: String
    let interfaceName: String
    let kind: DiagnosticRunner.DiagnosticKind
    let onCompleted: (ChangeControl) -> Void
    let onFailed: (String) -> Void

    @EnvironmentObject private var auth: AuthStore
    @State private var phase: Phase = .submitting
    @State private var ccId: String?

    enum Phase: Equatable {
        case submitting
        case awaitingApproval
        case starting
        case running
        case terminal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                runHeader
                stepperCard
                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .task(id: "\(deviceId)|\(interfaceName)|\(kind.actionKey)") {
            await driveRun()
        }
    }

    // MARK: - Header

    private var runHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Running diagnostic…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Brand.graphite)
            }
            Text("\(kind.displayName) on \(interfaceName) (\(deviceId))")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Brand.slate)
            if let ccId {
                Text("Change Control ID: \(ccId)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Brand.slate)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stepper

    private var stepperCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            step(label: "Submitted", state: stepState(.submitting))
            stepDivider()
            step(label: "Approved", state: stepState(.awaitingApproval))
            stepDivider()
            step(label: "Started", state: stepState(.starting))
            stepDivider()
            step(label: "Running on device", state: stepState(.running))
            stepDivider()
            step(label: "Completed", state: phase == .terminal ? .done : .pending)
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private enum StepState { case pending, active, done }

    private func stepState(_ at: Phase) -> StepState {
        // Order: submitting → awaitingApproval → starting → running → terminal
        let order: [Phase] = [.submitting, .awaitingApproval, .starting, .running, .terminal]
        guard let cur = order.firstIndex(of: phase),
              let me  = order.firstIndex(of: at) else {
            return .pending
        }
        if me < cur { return .done }
        if me == cur { return .active }
        return .pending
    }

    private func step(label: String, state: StepState) -> some View {
        HStack(spacing: 12) {
            stepGlyph(state: state)
            Text(label)
                .font(.system(size: 14, weight: state == .active ? .semibold : .regular))
                .foregroundStyle(state == .pending ? Brand.slate : Brand.graphite)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func stepGlyph(state: StepState) -> some View {
        Group {
            switch state {
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 18))
            case .active:
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            case .pending:
                Image(systemName: "circle")
                    .foregroundStyle(Brand.mist)
                    .font(.system(size: 18))
            }
        }
        .frame(width: 22, height: 22)
    }

    private func stepDivider() -> some View {
        Rectangle()
            .fill(Brand.mist.opacity(0.4))
            .frame(width: 2, height: 14)
            .padding(.leading, 26)
    }

    // MARK: - Drive the runner

    @MainActor
    private func driveRun() async {
        guard let url = URL(string: auth.tenantURL) else {
            onFailed("Invalid tenant URL")
            return
        }
        let client = CVHTTPClient(tenantURL: url, jwt: auth.jwt)
        let runner = DiagnosticRunner(
            service: ChangeControlService(client: client),
            kind: kind,
            deviceId: deviceId,
            interfaceName: interfaceName
        )

        for await event in runner.run() {
            switch event {
            case .submitted(let id):
                ccId = id
                phase = .awaitingApproval
            case .approving:
                phase = .awaitingApproval
            case .starting:
                phase = .starting
            case .running:
                phase = .running
            case .completed(let snapshot):
                phase = .terminal
                onCompleted(snapshot)
            case .failed(let reason):
                phase = .terminal
                onFailed(reason)
            }
        }
    }
}
