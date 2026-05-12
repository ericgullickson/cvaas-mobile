import SwiftUI

struct LocateResultRow: View {
    let device: LocateResults.DeviceRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(Array(device.locations.prefix(3).enumerated()), id: \.offset) { _, loc in
                LocationLineView(location: loc)
            }
            if device.locations.count > 3 {
                Text("+\(device.locations.count - 3) more locations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(device.deviceName
                 ?? device.primaryIdentifier?.value
                 ?? device.id)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if let status = device.deviceStatus {
                StatusDot(status: status)
            }
        }
    }
}

private struct LocationLineView: View {
    let location: Location

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let host = location.deviceId {
                    Text(host)
                        .font(.subheadline.monospaced())
                        .lineLimit(1)
                }
                if let intf = location.interface {
                    Text("·").foregroundStyle(.tertiary)
                    Text(intf).font(.subheadline.monospaced()).lineLimit(1)
                }
                if let vlan = location.vlanId {
                    Text("·").foregroundStyle(.tertiary)
                    Text("VLAN \(vlan)").font(.subheadline)
                }
                Spacer(minLength: 6)
                if let lk = location.likelihood {
                    LikelihoodBadge(likelihood: lk)
                }
            }

            HStack(spacing: 6) {
                if let macType = location.macType, !macType.shortLabel.isEmpty {
                    Chip(text: macType.shortLabel)
                }
                if let explanations = location.explanationList?.values {
                    ForEach(Array(explanations.enumerated()), id: \.offset) { _, e in
                        Chip(text: e.displayName)
                    }
                }
                Spacer(minLength: 6)
                if let learned = location.learnedTime,
                   let date = ISO8601Date.parse(learned) {
                    Text(date, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.15))
            .clipShape(Capsule())
    }
}

private struct LikelihoodBadge: View {
    let likelihood: Likelihood
    var body: some View {
        Text(likelihood.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch likelihood {
        case .veryLikely: return .green
        case .likely: return .blue
        case .somewhatLikely: return .orange
        case .lessLikely: return .red
        case .unspecified: return .gray
        }
    }
}

private struct StatusDot: View {
    let status: DeviceStatus
    var body: some View {
        Circle()
            .fill(status == .active ? Color.green : Color.gray)
            .frame(width: 8, height: 8)
    }
}
