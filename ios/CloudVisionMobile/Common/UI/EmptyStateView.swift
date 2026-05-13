import SwiftUI

/// Custom empty state with a soft circular icon ground, headline, and message. Replaces
/// `ContentUnavailableView` everywhere the brand-graphite type and Brand.mist ground are
/// preferable to the iOS-system default (lighter, less branded).
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String?
    var action: Action?

    struct Action {
        let label: String
        let handler: () -> Void
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Brand.slate)
                .frame(width: 78, height: 78)
                .background(Brand.mist.opacity(0.45), in: Circle())
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Brand.graphite)
                if let message {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Brand.slate)
                        .multilineTextAlignment(.center)
                }
            }
            if let action {
                Button(action: action.handler) {
                    Text(action.label)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Brand.navy, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "magnifyingglass",
        title: "No ports match your filters.",
        message: "Try adjusting your search."
    )
}
