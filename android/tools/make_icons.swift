// Android launcher icon (adaptive: flag background + George Cross foreground), the 512 px Google Play
// icon and the 1024 × 500 feature graphic. Same design as shared/tools/make_icon.swift (iOS icon).
// Run from the repo root: swift android/tools/make_icons.swift
import AppKit

let root = FileManager.default.currentDirectoryPath
let res = root + "/android/app/src/main/res"
let play = root + "/android/play"

let red = CGColor(srgbRed: 0.812, green: 0.078, blue: 0.169, alpha: 1)
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
let silver = CGColor(srgbRed: 0.66, green: 0.67, blue: 0.69, alpha: 1)
let silverDark = CGColor(srgbRed: 0.45, green: 0.46, blue: 0.48, alpha: 1)

func context(_ w: Int, _ h: Int, alpha: Bool) -> CGContext {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: (alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)   // top-down like the iOS script
    return ctx
}

func save(_ ctx: CGContext, _ path: String) {
    try! FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                             withIntermediateDirectories: true)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path.replacingOccurrences(of: root + "/", with: ""))")
}

/// The design in "icon units" (the iOS icon is 1024 units square); `t` maps them to the canvas.
func drawFlag(_ ctx: CGContext, canvas: CGRect, t: CGAffineTransform) {
    ctx.setFillColor(red); ctx.fill(canvas)
    ctx.saveGState(); ctx.concatenate(t)
    ctx.setStrokeColor(white); ctx.setLineWidth(210)
    ctx.move(to: CGPoint(x: -2000, y: -2000)); ctx.addLine(to: CGPoint(x: 3024, y: 3024)); ctx.strokePath()
    ctx.restoreGState()
}

func drawCross(_ ctx: CGContext, t: CGAffineTransform, color: CGColor? = nil) {
    ctx.saveGState(); ctx.concatenate(t)
    let c = CGPoint(x: 700, y: 324), arm = 130.0, half = 42.0
    func cross(_ inset: Double) -> CGPath {
        let p = CGMutablePath(), a = arm - inset, h = half - inset
        p.addRect(CGRect(x: c.x - h, y: c.y - a, width: 2 * h, height: 2 * a))
        p.addRect(CGRect(x: c.x - a, y: c.y - h, width: 2 * a, height: 2 * h))
        return p
    }
    if let color {   // monochrome layer: just the outline shape
        ctx.setFillColor(color); ctx.addPath(cross(-12)); ctx.fillPath()
    } else {
        ctx.setFillColor(white); ctx.addPath(cross(-12)); ctx.fillPath()
        ctx.setFillColor(silver); ctx.addPath(cross(0)); ctx.fillPath()
        ctx.setStrokeColor(silverDark); ctx.setLineWidth(10)
        ctx.move(to: CGPoint(x: c.x, y: c.y - arm + 18)); ctx.addLine(to: CGPoint(x: c.x, y: c.y + arm - 18))
        ctx.move(to: CGPoint(x: c.x - arm + 18, y: c.y)); ctx.addLine(to: CGPoint(x: c.x + arm - 18, y: c.y))
        ctx.strokePath()
        ctx.setFillColor(silver); ctx.fillEllipse(in: CGRect(x: c.x - 40, y: c.y - 40, width: 80, height: 80))
        ctx.setStrokeColor(silverDark); ctx.setLineWidth(8)
        ctx.strokeEllipse(in: CGRect(x: c.x - 40, y: c.y - 40, width: 80, height: 80))
    }
    ctx.restoreGState()
}

// Adaptive icon layers: 108 dp canvas, of which the middle 72 dp is the visible "icon".
// The iOS icon square maps onto that middle 72 dp, so the cross stays inside the safe zone.
for (folder, px) in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)] {
    let s = CGFloat(px), t = CGAffineTransform(translationX: s / 6, y: s / 6).scaledBy(x: s * 2 / 3 / 1024, y: s * 2 / 3 / 1024)
    let canvas = CGRect(x: 0, y: 0, width: s, height: s)
    let bg = context(px, px, alpha: false); drawFlag(bg, canvas: canvas, t: t)
    save(bg, "\(res)/mipmap-\(folder)/ic_launcher_background.png")
    let fg = context(px, px, alpha: true); drawCross(fg, t: t)
    save(fg, "\(res)/mipmap-\(folder)/ic_launcher_foreground.png")
    let mono = context(px, px, alpha: true); drawCross(mono, t: t, color: white)
    save(mono, "\(res)/mipmap-\(folder)/ic_launcher_monochrome.png")
}

// Google Play icon: 512 × 512, full square (Play applies its own rounding).
do {
    let ctx = context(512, 512, alpha: false)
    let t = CGAffineTransform(scaleX: 0.5, y: 0.5)
    drawFlag(ctx, canvas: CGRect(x: 0, y: 0, width: 512, height: 512), t: t); drawCross(ctx, t: t)
    save(ctx, "\(play)/icon-512.png")
}

// Feature graphic: 1024 × 500, the opening-screen photo with icon and name.
do {
    let W = 1024.0, H = 500.0
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let photo = NSImage(contentsOfFile: root + "/ios/DiveMalta/Assets.xcassets/Splash.imageset/Splash.jpg")!
        .cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let scale = max(W / Double(photo.width), H / Double(photo.height))
    let pw = Double(photo.width) * scale, ph = Double(photo.height) * scale
    ctx.interpolationQuality = .high
    ctx.draw(photo, in: CGRect(x: (W - pw) * 0.42, y: (H - ph) * 0.5, width: pw, height: ph))
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [
        CGColor(srgbRed: 0.02, green: 0.08, blue: 0.16, alpha: 0.8), CGColor(srgbRed: 0.02, green: 0.08, blue: 0.16, alpha: 0)
    ] as CFArray, locations: [0, 0.75])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: W, y: 0), options: [])
    // Icon (rounded square) on the left.
    let iconSize = 150.0, iconRect = CGRect(x: 70, y: (H - iconSize) / 2 + 60, width: iconSize, height: iconSize)
    let icon = context(512, 512, alpha: true)
    let it = CGAffineTransform(scaleX: 0.5, y: 0.5)
    drawFlag(icon, canvas: CGRect(x: 0, y: 0, width: 512, height: 512), t: it); drawCross(icon, t: it)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: iconRect, cornerWidth: 34, cornerHeight: 34, transform: nil)); ctx.clip()
    ctx.draw(icon.makeImage()!, in: iconRect)
    ctx.restoreGState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.45); shadow.shadowBlurRadius = 6
    let title = NSFont.systemFont(ofSize: 84, weight: .bold)
    NSAttributedString(string: "Dive Malta", attributes: [.font: title, .foregroundColor: NSColor.white, .shadow: shadow])
        .draw(at: CGPoint(x: 66, y: 110))
    NSAttributedString(string: "Dive sites of Malta, Gozo and Comino · offline", attributes: [
        .font: NSFont.systemFont(ofSize: 28, weight: .semibold), .foregroundColor: NSColor.white, .shadow: shadow,
    ]).draw(at: CGPoint(x: 70, y: 66))
    NSGraphicsContext.restoreGraphicsState()
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! FileManager.default.createDirectory(atPath: play, withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(play)/feature-graphic-1024x500.png"))
    print("Wrote android/play/feature-graphic-1024x500.png")
}
