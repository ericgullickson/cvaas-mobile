import SwiftUI

@main
struct CloudVisionMobileApp: App {
    @StateObject private var auth = AuthStore()

    init() {
        Appearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(auth)
        }
    }
}
