import SwiftUI

struct AlertsListView: View {
    let alerts: [Event]
    let hostname: String?

    private var sorted: [Event] {
        alerts.sorted { ($0.severity ?? .unspecified) > ($1.severity ?? .unspecified) }
    }

    var body: some View {
        List {
            ForEach(sorted, id: \.stableId) { event in
                EventRowView(event: event)
            }
        }
        .navigationTitle("Active alerts")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if alerts.isEmpty {
                ContentUnavailableView(
                    "No active alerts",
                    systemImage: "checkmark.circle",
                    description: Text(hostname.map { "\($0) has no firing alerts." } ?? "No active alerts.")
                )
            }
        }
    }
}
