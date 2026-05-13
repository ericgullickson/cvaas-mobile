import SwiftUI

/// Top-level container with a **custom** navy tab bar (per PRD §9 visual identity).
///
/// We deliberately do NOT use SwiftUI's `TabView` here. iOS 26's default tab bar is a
/// translucent floating "liquid glass" pill that overrides every standard appearance API
/// (`UITabBarAppearance.backgroundColor`, `backgroundEffect = nil`, `.toolbarBackground`),
/// making it impossible to deliver the solid-navy bar the Direction 3 mockup specifies.
///
/// Building our own is ~40 lines and gives pixel fidelity. The visible trade-off versus the
/// system bar: we lose the iOS 26 scroll-minimize behavior. We keep VoiceOver labels via
/// explicit `accessibilityLabel` per item.
struct RootView: View {
    @State private var selected: AppTab = .devices

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            CustomTabBar(selected: $selected)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var content: some View {
        switch selected {
        case .devices: SwitchesView()
        case .alerts:  AlertsView()
        case .tools:   LocateView()
        case .more:    MoreView()
        }
    }
}

// MARK: - Tab model

enum AppTab: Hashable, CaseIterable {
    case devices, alerts, tools, more

    var label: String {
        switch self {
        case .devices: return "Devices"
        case .alerts:  return "Alerts"
        case .tools:   return "Tools"
        case .more:    return "More"
        }
    }

    var icon: String {
        switch self {
        case .devices: return "rectangle.stack.fill"
        case .alerts:  return "bell.fill"
        case .tools:   return "wrench.and.screwdriver.fill"
        case .more:    return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Custom tab bar

private struct CustomTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selected == tab,
                    action: { selected = tab }
                )
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 22) // home indicator clearance
        .background(
            Brand.navy
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct TabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? .white : Color.white.opacity(0.55))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
