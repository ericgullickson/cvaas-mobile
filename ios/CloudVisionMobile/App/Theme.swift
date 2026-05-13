import SwiftUI
import UIKit

/// Arista brand palette and typography tokens. The palette is fixed per PRD §9.1 —
/// these six hex values are the entire chrome surface; status semantics (green/orange/red)
/// stay on the iOS system semantic colors per PRD §9.2.
enum Brand {
    static let navy     = Color(red: 0x16/255.0, green: 0x31/255.0, blue: 0x5A/255.0)
    static let steel    = Color(red: 0x25/255.0, green: 0x67/255.0, blue: 0x8D/255.0)
    static let sky      = Color(red: 0x55/255.0, green: 0x88/255.0, blue: 0xB7/255.0)
    static let graphite = Color(red: 0x58/255.0, green: 0x59/255.0, blue: 0x5A/255.0)
    static let slate    = Color(red: 0x92/255.0, green: 0x95/255.0, blue: 0x98/255.0)
    static let mist     = Color(red: 0xBB/255.0, green: 0xBD/255.0, blue: 0xBE/255.0)
}

/// UIKit twins for places SwiftUI can't reach (UITabBarAppearance, UINavigationBarAppearance).
extension UIColor {
    static let brandNavy     = UIColor(red: 0x16/255.0, green: 0x31/255.0, blue: 0x5A/255.0, alpha: 1)
    static let brandSteel    = UIColor(red: 0x25/255.0, green: 0x67/255.0, blue: 0x8D/255.0, alpha: 1)
    static let brandSky      = UIColor(red: 0x55/255.0, green: 0x88/255.0, blue: 0xB7/255.0, alpha: 1)
    static let brandGraphite = UIColor(red: 0x58/255.0, green: 0x59/255.0, blue: 0x5A/255.0, alpha: 1)
    static let brandSlate    = UIColor(red: 0x92/255.0, green: 0x95/255.0, blue: 0x98/255.0, alpha: 1)
    static let brandMist     = UIColor(red: 0xBB/255.0, green: 0xBD/255.0, blue: 0xBE/255.0, alpha: 1)
}

/// Typography. SF Pro Display for titles, SF Pro Text for body, SF Mono for identifiers.
/// The iOS default font *is* SF Pro; calling out roles here gives us a single place to tune
/// weights/sizes without grep-spelunking through 14 views.
enum TypeScale {
    static let largeTitle = Font.system(size: 28, weight: .semibold, design: .default)
    static let sectionLabel = Font.system(size: 11, weight: .semibold, design: .default)
        .smallCaps()
    static let identifier = Font.system(.body, design: .monospaced)
    static let identifierLarge = Font.system(size: 22, weight: .medium, design: .monospaced)
    static let identifierSmall = Font.system(.caption, design: .monospaced)
}

/// Global UIKit appearance — tab bar and nav bar both use navy.
///
/// iOS 26 introduces a translucent "liquid glass" tab bar that overrides
/// `configureWithOpaqueBackground()` unless we also clear `backgroundEffect`. We do that
/// here and apply the same appearance to all three layout variants (stacked / inline /
/// compactInline) so rotation and split-screen states stay branded.
enum Appearance {
    static func apply() {
        applyTabBar()
        applyNavigationBar()
    }

    private static func applyTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .brandNavy
        appearance.backgroundEffect = nil    // disable iOS 26 liquid-glass material
        appearance.shadowColor = .clear      // remove the hairline separator above the bar

        let unselected: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.55),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        let selected: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            layout.normal.iconColor = UIColor.white.withAlphaComponent(0.55)
            layout.selected.iconColor = .white
            layout.normal.titleTextAttributes = unselected
            layout.selected.titleTextAttributes = selected
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = .white
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.55)
    }

    private static func applyNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .brandNavy
        appearance.backgroundEffect = nil
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }
}
