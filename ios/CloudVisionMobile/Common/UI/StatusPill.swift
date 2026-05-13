import SwiftUI

/// Unified status pill. One source of truth for "HEALTHY" / "PoE 30W" / "Link Down" / "Not PoE"
/// styling. Three intents map to semantic system colors so functional cues stay legible per
/// PRD §9.2 (status colors are NOT remapped to brand blues).
///
/// - `success` / `warning` / `danger` use system green/orange/red.
/// - `neutral` and `info` use the brand grayscale ramp + steel blue for informational labels
///   (e.g., "Not PoE" — not an error, just a capability statement).
struct StatusPill: View {
    let label: String
    var intent: Intent = .neutral
    var style: Style = .filled
    var size: Size = .regular

    enum Intent {
        case success, warning, danger, neutral, info
    }

    enum Style {
        case filled, outlined
    }

    enum Size {
        case small, regular
    }

    var body: some View {
        Text(label)
            .font(font)
            .tracking(0.5)
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: style == .outlined ? 1 : 0)
            )
    }

    // MARK: - Tokens

    private var font: Font {
        size == .small
            ? .system(size: 10, weight: .semibold)
            : .system(size: 11, weight: .semibold)
    }

    private var horizontalPadding: CGFloat { size == .small ? 7 : 9 }
    private var verticalPadding: CGFloat   { size == .small ? 2 : 4 }

    private var intentColor: Color {
        switch intent {
        case .success: return .green
        case .warning: return .orange
        case .danger:  return .red
        case .neutral: return Brand.slate
        case .info:    return Brand.steel
        }
    }

    private var foreground: Color {
        // Outlined: intent color. Filled: intent color but slightly darker to read on tint.
        switch style {
        case .filled:   return intentColor
        case .outlined: return intentColor
        }
    }

    private var background: Color {
        switch style {
        case .filled:   return intentColor.opacity(0.18)
        case .outlined: return .clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .filled:   return .clear
        case .outlined: return intentColor.opacity(0.6)
        }
    }
}

#Preview("StatusPill — intents") {
    VStack(alignment: .leading, spacing: 12) {
        StatusPill(label: "HEALTHY", intent: .success)
        StatusPill(label: "PoE 30W", intent: .success, style: .outlined)
        StatusPill(label: "PoE 7.8W", intent: .warning, style: .outlined)
        StatusPill(label: "Link Down", intent: .danger)
        StatusPill(label: "PoE Off", intent: .neutral)
        StatusPill(label: "Not PoE", intent: .info)
    }
    .padding()
}
