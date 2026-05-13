import SwiftUI

/// Full-screen 24-hour event list scoped to one device. Reached from the Quick Actions grid on
/// Device Detail. Reuses the existing per-event filter logic from `Event.mentionsDevice`.
struct DeviceEventsView: View {
    let deviceId: String
    let hostname: String?
    let events: [Event]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if events.isEmpty {
                    EmptyStateView(
                        systemImage: "list.bullet.rectangle",
                        title: "No recent events",
                        message: "Nothing reported in the last 24 hours for this device."
                    )
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.stableId) { index, event in
                            EventRowView(event: event)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            if index < events.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                Color.clear.frame(height: 100)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(hostname ?? "Events")
        .navigationBarTitleDisplayMode(.inline)
    }
}
