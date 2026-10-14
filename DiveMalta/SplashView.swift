import SwiftUI

/// Opening screen: the Blue Hole at Dwejra, Gozo.
/// Photo by Diego Delso (delso.photo), CC BY-SA 4.0, resized:
/// https://commons.wikimedia.org/wiki/File:Agujero_Azul,_isla_de_Gozo,_Malta,_2021-08-22,_DD_71.jpg
struct SplashView: View {
    static let photoCredit = "Photo: Blue Hole, Gozo · Diego Delso · CC BY-SA 4.0"
    static let photoURL = URL(string: "https://commons.wikimedia.org/wiki/File:Agujero_Azul,_isla_de_Gozo,_Malta,_2021-08-22,_DD_71.jpg")!

    var body: some View {
        GeometryReader { geo in
            // The photo is 3:2. Fill the screen and, on a tall screen, shift it so the Blue Hole pool
            // and the cliff (about 60% across the photo) stay in view, without showing an edge.
            let width = max(geo.size.width, geo.size.height * 1.5)
            let spare = (width - geo.size.width) / 2
            Image("Splash")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: geo.size.height)
                .offset(x: min(spare, max(-spare, (0.5 - 0.6) * width)))
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
        .overlay(alignment: .bottom) {
            Text(Self.photoCredit)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.bottom, 16)
        }
        .accessibilityElement(children: .combine)
    }
}
