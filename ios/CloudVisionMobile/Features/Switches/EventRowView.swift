import SwiftUI

struct EventRowView: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                severityIcon
                Text(event.title ?? event.eventType ?? "Event")
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if let date = event.startDate {
                    Text(date, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let desc = event.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 6) {
                if let evtType = event.eventType, !evtType.isEmpty {
                    Text(evtType)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                if !event.isActive {
                    Text("RESOLVED")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var severityIcon: some View {
        let s = event.severity ?? .unspecified
        let (name, color): (String, Color) = {
            switch s {
            case .critical: return ("exclamationmark.octagon.fill", .red)
            case .error: return ("exclamationmark.triangle.fill", .red)
            case .warning: return ("exclamationmark.triangle.fill", .orange)
            case .info: return ("info.circle.fill", .blue)
            case .debug: return ("ladybug.fill", .gray)
            case .unspecified: return ("circle.fill", .gray)
            }
        }()
        return Image(systemName: name)
            .foregroundStyle(color)
            .font(.caption)
    }
}
