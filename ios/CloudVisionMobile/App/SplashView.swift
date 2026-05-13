import SwiftUI

/// Brand splash shown for ~700ms on app launch (over the navy `UILaunchScreen` background so the
/// transition from system launch → SwiftUI is seamless). After the dwell, fades into RootView.
struct SplashView: View {
    @State private var showRoot = false
    @State private var wordmarkOpacity = 0.0
    @State private var captionOpacity = 0.0

    var body: some View {
        ZStack {
            if showRoot {
                RootView()
                    .transition(.opacity)
            } else {
                splash
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showRoot)
    }

    private var splash: some View {
        ZStack {
            Brand.navy.ignoresSafeArea()
            VStack(spacing: 18) {
                Image("AristaLogoWhite")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220)
                    .opacity(wordmarkOpacity)
                Rectangle()
                    .fill(Brand.sky)
                    .frame(width: 80, height: 2)
                    .opacity(wordmarkOpacity)
                Text("Connecting securely…")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Brand.mist)
                    .opacity(captionOpacity)
                    .padding(.top, 6)
            }
        }
        .task {
            withAnimation(.easeOut(duration: 0.4)) { wordmarkOpacity = 1.0 }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.3)) { captionOpacity = 1.0 }
            try? await Task.sleep(for: .milliseconds(700))
            showRoot = true
        }
    }
}
