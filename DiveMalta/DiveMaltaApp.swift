import SwiftUI

@main
struct DiveMaltaApp: App {
    // In screenshot mode the opening screen only shows for the "splash" scene, and then stays.
    @State private var showSplash = ScreenshotScene.current == nil || ScreenshotScene.current == .splash

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .onTapGesture { withAnimation(.easeOut(duration: 0.4)) { showSplash = false } }
                        .zIndex(1)
                }
            }
            .task {
                guard ScreenshotScene.current == nil else { return }
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
    }
}
