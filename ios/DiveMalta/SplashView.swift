import SwiftUI

/// Opening screen: sunset over the cliffs of Gozo. Photo by the app's author, all rights reserved.
struct SplashView: View {
    private static let photo = UIImage(named: "Splash")
    /// Where the interesting part of the photo is, across its width (the sun and the cliff edge).
    private static let focusX = 0.5

    var body: some View {
        GeometryReader { geo in
            // Fill the screen and, on a tall screen, shift the photo so its focus stays in view,
            // without showing an edge.
            let aspect = Self.photo.map { $0.size.width / $0.size.height } ?? 4.0 / 3.0
            let width = max(geo.size.width, geo.size.height * aspect)
            let spare = (width - geo.size.width) / 2
            Image("Splash")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: geo.size.height)
                .offset(x: min(spare, max(-spare, (0.5 - Self.focusX) * width)))
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .overlay {
            LinearGradient(colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            VStack(spacing: 6) {
                Text("Dive Malta")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("Dive sites of Malta, Gozo and Comino")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 6)
            .padding(.top, 80)
        }
        .accessibilityElement(children: .combine)
    }
}
