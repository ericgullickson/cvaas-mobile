import SwiftUI

/// Branded loading placeholder for list rows. Replaces `ProgressView` in places where we know
/// the shape of the upcoming content — a shimmer-style skeleton communicates "data is on its
/// way" more reassuringly than a generic spinner, and lets the user count rows pre-arrival.
struct SkeletonRow: View {
    var height: CGFloat = 56
    /// When true, the row includes a leading 4pt color strip — matches the redesigned
    /// `PortRow` so skeleton state visually aligns with loaded state.
    var showLeadingEdge: Bool = true

    @State private var animating = false

    var body: some View {
        HStack(spacing: 14) {
            if showLeadingEdge {
                Rectangle()
                    .fill(Brand.mist)
                    .frame(width: 4)
            }
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerFill)
                    .frame(width: 100, height: 16)
                RoundedRectangle(cornerRadius: 3)
                    .fill(shimmerFill.opacity(0.7))
                    .frame(width: 60, height: 11)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 12)
                .fill(shimmerFill.opacity(0.5))
                .frame(width: 56, height: 22)
                .padding(.trailing, 8)
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: animating)
        .onAppear { animating = true }
    }

    private var shimmerFill: Color {
        animating ? Brand.mist.opacity(0.45) : Brand.mist
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(0..<5, id: \.self) { _ in
            SkeletonRow()
            Divider().padding(.leading, 18)
        }
    }
    .padding(.vertical)
}
