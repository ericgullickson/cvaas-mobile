import SwiftUI

struct ConfigureCTA: View {
    let featureName: String

    var body: some View {
        ContentUnavailableView {
            Label("Not configured", systemImage: "gearshape.fill")
        } description: {
            Text("Set your tenant URL and service-account JWT in Settings to use \(featureName).")
        }
    }
}
