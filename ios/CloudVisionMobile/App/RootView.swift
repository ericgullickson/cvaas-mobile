import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            LocateView()
                .tabItem { Label("Locate", systemImage: "magnifyingglass") }

            SwitchesView()
                .tabItem { Label("Switches", systemImage: "network") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
