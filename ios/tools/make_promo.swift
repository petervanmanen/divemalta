// App Store promotional images for Dive Malta (App Store Connect › Creative assets specifications):
//   universal-5244x2950   16:9, usable for both the product page header and search results (PNG only)
//   header-3840x1646      21:9, product page header
//   search-3840x2560      3:2, search results (allowed: 1920 × 1280 up to 3840 × 2560) Your sunset photo as background, icon, name and tagline on the left, an iPhone
// screenshot on the right. Run from the repo root after ios/tools/screenshots.sh:
//   swift ios/tools/make_promo.swift
// Output: ios/promo/*.png (exact sizes, RGB without alpha channel).
import AppKit

let root = FileManager.default.currentDirectoryPath
let photoPath = root + "/ios/DiveMalta/Assets.xcassets/Splash.imageset/Splash.jpg"
let iconPath = root + "/ios/DiveMalta/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let phonePath = root + "/ios/screenshots/iPhone-18-Pro-Max/3-contours.jpg"

func load(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOfFile: path) else { fatalError("Missing \(path) (run ios/tools/screenshots.sh first)") }
    return image
}
let photo = load(photoPath), icon = load(iconPath), phone = load(phonePath)

func cg(_ image: NSImage) -> CGImage { image.cgImage(forProposedRect: nil, context: nil, hints: nil)! }

/// Draw `image` to fill `rect`, cropping around a focus point (0…1 in the image).
func drawFill(_ image: CGImage, in rect: CGRect, focus: CGPoint, ctx: CGContext) {
    let iw = CGFloat(image.width), ih = CGFloat(image.height)
    let scale = max(rect.width / iw, rect.height / ih)
    let w = iw * scale, h = ih * scale
    let x = min(rect.minX, max(rect.maxX - w, rect.midX - focus.x * w))
    let y = min(rect.minY, max(rect.maxY - h, rect.midY - (1 - focus.y) * h))
    ctx.saveGState()
    ctx.clip(to: rect)
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: x, y: y, width: w, height: h))
    ctx.restoreGState()
}

func make(width: Int, height: Int, name: String) {
    let W = CGFloat(width), H = CGFloat(height)
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let full = CGRect(x: 0, y: 0, width: W, height: H)

    // Background: the photo, keeping the sun and cliff edge in view right of centre.
    drawFill(cg(photo), in: full, focus: CGPoint(x: 0.42, y: 0.55), ctx: ctx)

    // Darken the left side for the text.
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [
        CGColor(srgbRed: 0.02, green: 0.08, blue: 0.16, alpha: 0.82),
        CGColor(srgbRed: 0.02, green: 0.08, blue: 0.16, alpha: 0.35),
        CGColor(srgbRed: 0.02, green: 0.08, blue: 0.16, alpha: 0.0),
    ] as CFArray, locations: [0, 0.45, 0.75])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: W, y: 0), options: [])

    // iPhone screenshot on the right, with a rounded frame and a soft shadow.
    let phoneH = H * 0.86
    let phoneW = phoneH * CGFloat(cg(phone).width) / CGFloat(cg(phone).height)
    let phoneRect = CGRect(x: W - phoneW - W * 0.07, y: (H - phoneH) / 2, width: phoneW, height: phoneH)
    let radius = phoneW * 0.12, bezel = phoneW * 0.03
    let frame = phoneRect.insetBy(dx: -bezel, dy: -bezel)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -H * 0.01), blur: H * 0.05,
                  color: CGColor(gray: 0, alpha: 0.55))
    ctx.addPath(CGPath(roundedRect: frame, cornerWidth: radius + bezel, cornerHeight: radius + bezel, transform: nil))
    ctx.setFillColor(CGColor(gray: 0.08, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: phoneRect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(cg(phone), in: phoneRect)
    ctx.restoreGState()

    // Icon, name and tagline on the left, vertically centred.
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ns
    let left = W * 0.07
    let iconSize = H * 0.2
    let titleSize = H * 0.13, tagSize = H * 0.045
    let blockH = iconSize + H * 0.05 + titleSize * 1.15 + H * 0.045 + tagSize * 1.3 * 2
    var y = (H + blockH) / 2

    y -= iconSize
    let iconRect = CGRect(x: left, y: y, width: iconSize, height: iconSize)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -iconSize * 0.03), blur: iconSize * 0.12,
                  color: CGColor(gray: 0, alpha: 0.5))
    ctx.addPath(CGPath(roundedRect: iconRect, cornerWidth: iconSize * 0.225, cornerHeight: iconSize * 0.225, transform: nil))
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: iconRect, cornerWidth: iconSize * 0.225, cornerHeight: iconSize * 0.225, transform: nil))
    ctx.clip()
    ctx.draw(cg(icon), in: iconRect)
    ctx.restoreGState()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.45)
    shadow.shadowBlurRadius = H * 0.012
    shadow.shadowOffset = NSSize(width: 0, height: -H * 0.003)

    y -= H * 0.05 + titleSize * 1.15
    let roundedBold = NSFont.systemFont(ofSize: titleSize, weight: .bold).fontDescriptor.withDesign(.rounded)
        .flatMap { NSFont(descriptor: $0, size: titleSize) } ?? NSFont.systemFont(ofSize: titleSize, weight: .bold)
    NSAttributedString(string: "Dive Malta", attributes: [
        .font: roundedBold, .foregroundColor: NSColor.white, .shadow: shadow,
    ]).draw(at: CGPoint(x: left - titleSize * 0.04, y: y))

    let para = NSMutableParagraphStyle()
    para.lineSpacing = tagSize * 0.25
    y -= H * 0.045 + tagSize * 1.3 * 2
    NSAttributedString(string: "Dive sites of Malta, Gozo and Comino\nwith depth contours, offline", attributes: [
        .font: NSFont.systemFont(ofSize: tagSize, weight: .semibold),
        .foregroundColor: NSColor(white: 1, alpha: 0.95), .shadow: shadow, .paragraphStyle: para,
    ]).draw(in: CGRect(x: left, y: y, width: phoneRect.minX - left - W * 0.04, height: tagSize * 1.3 * 2 + tagSize))
    NSGraphicsContext.restoreGraphicsState()

    let out = root + "/ios/promo/\(name).png"
    try! FileManager.default.createDirectory(atPath: root + "/ios/promo", withIntermediateDirectories: true)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: out))
    print("Wrote \(out) (\(width) × \(height))")
}

make(width: 5244, height: 2950, name: "universal-5244x2950")
make(width: 3840, height: 1646, name: "header-3840x1646")
make(width: 3840, height: 2560, name: "search-3840x2560")
