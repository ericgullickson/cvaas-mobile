import SwiftUI

/// Navy hero band that introduces a detail screen with the device's primary identity:
/// hostname (large, white) + status pill, with model/address as a secondary line, and an
/// optional star toggle for local favoriting (UserDefaults-backed via `FavoritesStore`).
///
/// Visual goal per Direction 3: 200ms before the user has parsed the rest of the screen they
/// should know exactly which device they're on and whether it's healthy.
struct DeviceHeroBand: View {
    let hostname: String
    let model: String?
    let address: String?
    let isHealthy: Bool
    @Binding var isFavorite: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Brand.navy, Brand.navy.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(hostname)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    StatusPill(
                        label: isHealthy ? "HEALTHY" : "UNHEALTHY",
                        intent: isHealthy ? .success : .danger
                    )
                }
                if model != nil || address != nil {
                    Text(metadataLine)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(Brand.mist)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            // Favorite star — top-trailing, mirrors mockup
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isFavorite.toggle()
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isFavorite ? .yellow : .white.opacity(0.6))
                            .padding(8)
                    }
                    .accessibilityLabel(isFavorite ? "Unfavorite" : "Favorite")
                }
                Spacer()
            }
        }
        .frame(minHeight: 110)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    private var metadataLine: String {
        [model, address].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " • ")
    }
}

#Preview("Hero — healthy") {
    DeviceHeroBand(
        hostname: "DC1-LEAF1",
        model: "7050TX3",
        address: "192.168.1.101",
        isHealthy: true,
        isFavorite: .constant(true)
    )
}

#Preview("Hero — degraded") {
    DeviceHeroBand(
        hostname: "DC1-SPINE2-VERY-LONG-HOSTNAME",
        model: "7280R3",
        address: "10.0.0.2",
        isHealthy: false,
        isFavorite: .constant(false)
    )
}
