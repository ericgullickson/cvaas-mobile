import Charts
import SwiftUI

/// Two-line throughput chart for one interface: RX (incoming) and TX (outgoing) in bps.
/// Y-axis auto-scales to bps / Kbps / Mbps / Gbps based on the peak rate; x-axis is the
/// time window contained in the supplied `CounterSeries`.
struct InterfaceCountersChart: View {
    let series: CounterSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            legend
            chart
                .frame(height: 180)
            footer
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            legendDot(color: Brand.sky,  label: "RX", value: formatBps(series.peakRxBps))
            legendDot(color: Brand.navy, label: "TX", value: formatBps(series.peakTxBps))
            Spacer()
        }
    }

    private func legendDot(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Brand.graphite)
            Text("peak \(value)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Brand.slate)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(series.rxBps) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("bps",  point.bps)
                )
                .foregroundStyle(by: .value("Direction", "RX"))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.75))
            }
            ForEach(series.txBps) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("bps",  point.bps)
                )
                .foregroundStyle(by: .value("Direction", "TX"))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.75))
            }
        }
        .chartForegroundStyleScale([
            "RX": Brand.sky,
            "TX": Brand.navy,
        ])
        .chartLegend(.hidden)
        .chartXScale(domain: series.windowStart...series.windowEnd)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Brand.mist.opacity(0.6))
                AxisValueLabel {
                    if let bps = value.as(Double.self) {
                        Text(formatBps(bps))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Brand.slate)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Brand.mist.opacity(0.6))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.hour().minute())
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Brand.slate)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(footerText)
                .font(.system(size: 11))
                .foregroundStyle(Brand.slate)
            Spacer()
        }
    }

    private var footerText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let from = formatter.string(from: series.windowStart)
        let to = formatter.string(from: series.windowEnd)
        return "\(from)–\(to) · derived from byte counters"
    }

    // MARK: - Formatting

    private func formatBps(_ bps: Double) -> String {
        if bps >= 1_000_000_000 { return String(format: "%.2f Gbps", bps / 1_000_000_000) }
        if bps >= 1_000_000     { return String(format: "%.1f Mbps", bps / 1_000_000) }
        if bps >= 1_000         { return String(format: "%.1f Kbps", bps / 1_000) }
        return String(format: "%.0f bps", bps)
    }
}
