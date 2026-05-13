import SwiftUI

/// Small-caps section header (e.g., "OVERVIEW", "QUICK ACTIONS", "RECENT ACTIVITY").
/// Visual replacement for `Section("Title")` headers when we want the custom card layout
/// rather than the iOS grouped-list default.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(TypeScale.sectionLabel)
            .tracking(1.4)
            .foregroundStyle(Brand.slate)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SectionLabel(text: "OVERVIEW")
        SectionLabel(text: "QUICK ACTIONS")
        SectionLabel(text: "RECENT ACTIVITY")
    }
    .padding()
}
