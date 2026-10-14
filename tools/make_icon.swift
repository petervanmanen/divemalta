// Draws the Dive Malta app icon: the dive flag (red with a white diagonal stripe) carrying the
// George Cross from the Maltese flag in its upper red corner, edged in white instead of red.
// Run: swift tools/make_icon.swift DiveMalta/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import CoreGraphics

let size = 1024.0
let red = CGColor(srgbRed: 0.812, green: 0.078, blue: 0.169, alpha: 1)      // Maltese red #CF142B
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
let silver = CGColor(srgbRed: 0.66, green: 0.67, blue: 0.69, alpha: 1)
let silverDark = CGColor(srgbRed: 0.45, green: 0.46, blue: 0.48, alpha: 1)

let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Work top-down like the flag is described.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// Dive flag: red field, white stripe from the top-left to the bottom-right corner.
ctx.setFillColor(red)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
ctx.setStrokeColor(white)
ctx.setLineWidth(210)
ctx.move(to: CGPoint(x: -100, y: -100))
ctx.addLine(to: CGPoint(x: size + 100, y: size + 100))
ctx.strokePath()

// George Cross: a silver cross, edged in white so it stands out on the red.
let centre = CGPoint(x: 700, y: 324)
let arm = 130.0, half = 42.0
func crossPath(inset: Double) -> CGPath {
    let p = CGMutablePath()
    let a = arm - inset, h = half - inset
    p.addRect(CGRect(x: centre.x - h, y: centre.y - a, width: 2 * h, height: 2 * a))
    p.addRect(CGRect(x: centre.x - a, y: centre.y - h, width: 2 * a, height: 2 * h))
    return p
}
ctx.setFillColor(white)
ctx.addPath(crossPath(inset: -12))
ctx.fillPath()
ctx.setFillColor(silver)
ctx.addPath(crossPath(inset: 0))
ctx.fillPath()
// A darker line down the middle of each arm gives the medal a little relief.
ctx.setStrokeColor(silverDark)
ctx.setLineWidth(10)
ctx.move(to: CGPoint(x: centre.x, y: centre.y - arm + 18)); ctx.addLine(to: CGPoint(x: centre.x, y: centre.y + arm - 18))
ctx.move(to: CGPoint(x: centre.x - arm + 18, y: centre.y)); ctx.addLine(to: CGPoint(x: centre.x + arm - 18, y: centre.y))
ctx.strokePath()
ctx.setFillColor(silver)
ctx.fillEllipse(in: CGRect(x: centre.x - 40, y: centre.y - 40, width: 80, height: 80))
ctx.setStrokeColor(silverDark)
ctx.setLineWidth(8)
ctx.strokeEllipse(in: CGRect(x: centre.x - 40, y: centre.y - 40, width: 80, height: 80))

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
