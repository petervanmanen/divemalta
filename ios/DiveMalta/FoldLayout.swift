import SwiftUI

/// Places its content like an overlay with `alignment`, but keeps it off the fold of a foldable
/// iPhone (iPhone Duo). Opened like a book, the fold runs top to bottom through the middle of the
/// map, right where the centred banner, toast and bottom bar would sit, so they move to the half on
/// the leading side of it (the map buttons are on the trailing side). Everywhere else, and when the
/// fold runs left to right (the open phone turned), it's a plain full-size overlay.
struct BesideFold<Content: View>: View {
    var alignment: Alignment
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            content
                .frame(width: geo.verticalFold?.minX ?? geo.size.width, height: geo.size.height,
                       alignment: alignment)
        }
    }
}

extension GeometryProxy {
    /// The fold in this view's coordinates (leading edge = 0), when it runs top to bottom through it.
    /// Read on every layout pass: the region only arrives after the first one.
    var verticalFold: CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        return reservedRegions(kind: .division)
            .first { $0.isActive && $0.frame.height > $0.frame.width && $0.frame.minX > 0 }?
            .frame
    }
}
