import SwiftUI

@main
struct DiveMaltaApp: App {
    @State private var showSplash = true

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
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
    }
}
