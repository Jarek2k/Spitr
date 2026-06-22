//
//  make_dmg_background.swift
//  Renders the DMG install-window background, matching the Spitr "signal" web
//  design: near-black base, faint grid, green glow, accent-green drag arrow.
//
//  Finder forces BLACK icon-label text whenever a background picture is set
//  (a documented limitation — no API to change it). To keep "Spitr" /
//  "Applications" readable on the dark ground we bake a soft light plate behind
//  each caption; the black text then sits on a light chip while the rest of the
//  window stays near-black.
//
//  Headless CoreGraphics — no AppKit window, no external tools. Run:
//      swift Scripts/assets/make_dmg_background.swift Scripts/assets/dmg-background.png
//
//  Window content is 660×420 pt; build_dmg.sh sets the Finder window and icon
//  positions to match (app at x≈165, Applications at x≈495, both y≈195 from top).
//

import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let W = 660, H = 420
guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: make_dmg_background.swift <out.png>\n".utf8))
    exit(2)
}
let outPath = CommandLine.arguments[1]

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("no context")
}

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}
let baseTop = rgb(0.055, 0.063, 0.067)   // #0e1011
let baseBot = rgb(0.031, 0.035, 0.039)   // #08090a
func mint(_ a: Double) -> CGColor { rgb(0.306, 0.941, 0.651, a) } // #4ef0a6

// CG origin is bottom-left; Finder icon y is from the top → cy = H - 195.
let cy = CGFloat(H - 195)
let cx = CGFloat(W) / 2

// 1) Base vertical gradient.
let base = CGGradient(colorsSpace: cs, colors: [baseBot, baseTop] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(base, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(H)), options: [])

// 2) Faint technical grid (like the site's grid-bg), 64px cells.
ctx.setStrokeColor(rgb(1, 1, 1, 0.05))
ctx.setLineWidth(1)
ctx.beginPath()
for x in stride(from: 0, through: W, by: 64) {
    ctx.move(to: CGPoint(x: Double(x), y: 0)); ctx.addLine(to: CGPoint(x: Double(x), y: Double(H)))
}
for y in stride(from: 0, through: H, by: 64) {
    ctx.move(to: CGPoint(x: 0, y: Double(y))); ctx.addLine(to: CGPoint(x: Double(W), y: Double(y)))
}
ctx.strokePath()

// 3) Vignette: darken edges, keep the icon row clear.
let vignette = CGGradient(colorsSpace: cs, colors: [baseBot.copy(alpha: 0)!, baseBot.copy(alpha: 0.85)!] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(vignette, startCenter: CGPoint(x: cx, y: cy), startRadius: 60,
                       endCenter: CGPoint(x: cx, y: cy), endRadius: CGFloat(W) * 0.62, options: [])

// 4) Green glow behind the centre (echoes the site's accent spotlight).
let glow = CGGradient(colorsSpace: cs, colors: [mint(0.20), mint(0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                       endCenter: CGPoint(x: cx, y: cy), endRadius: 240, options: [])

// 5) Accent-green drag arrow with a soft glow.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 16, color: mint(0.55))
ctx.setFillColor(mint(1))
let shaft = CGRect(x: 288, y: cy - 7, width: 56, height: 14)
ctx.addPath(CGPath(roundedRect: shaft, cornerWidth: 7, cornerHeight: 7, transform: nil))
ctx.fillPath()
ctx.beginPath()
ctx.move(to: CGPoint(x: 340, y: cy - 19))
ctx.addLine(to: CGPoint(x: 374, y: cy))
ctx.addLine(to: CGPoint(x: 340, y: cy + 19))
ctx.closePath()
ctx.fillPath()
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("no image") }
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dst = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("no destination")
}
CGImageDestinationAddImage(dst, image, nil)
guard CGImageDestinationFinalize(dst) else { fatalError("write failed") }
print("wrote \(outPath) (\(W)×\(H))")
