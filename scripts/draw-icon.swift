// Draws the Keylume app icon at 1024×1024 using the standard macOS icon grid
// (824 px rounded square, 100 px margin). Usage: swift scripts/draw-icon.swift out.png
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let cs = CGColorSpace(name: CGColorSpace.displayP3)!
guard let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                          space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// Body: rounded square on the macOS grid, with the grid's soft drop shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.35))
ctx.addPath(bodyPath)
ctx.setFillColor(color(0.07, 0.06, 0.12))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(bodyPath)
ctx.clip()

// Background: subtle light-to-dark, top to bottom (CG's origin is bottom-left).
let bg = CGGradient(colorsSpace: cs, colors: [color(0.20, 0.17, 0.33), color(0.05, 0.04, 0.10)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

// The "lume": a ring of spectrum colour behind the keycap.
let center = CGPoint(x: 512, y: 512)
let hues: [CGFloat] = [0.95, 0.08, 0.15, 0.33, 0.50, 0.62, 0.75, 0.95]
let ringColors = hues.map { NSColor(calibratedHue: $0, saturation: 0.85, brightness: 1, alpha: 1).cgColor }
let ring = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: ringColors as CFArray,
                      locations: nil)!
ctx.saveGState()
let outer = CGPath(ellipseIn: CGRect(x: center.x - 330, y: center.y - 330, width: 660, height: 660), transform: nil)
ctx.addPath(outer)
ctx.clip()
// Approximate a conic gradient with many thin wedges.
let steps = 360
for i in 0..<steps {
    let a0 = CGFloat(i) / CGFloat(steps) * 2 * .pi, a1 = CGFloat(i + 1) / CGFloat(steps) * 2 * .pi + 0.01
    let t = CGFloat(i) / CGFloat(steps)
    let idx = t * CGFloat(hues.count - 1)
    let lo = Int(idx), hi = min(lo + 1, hues.count - 1), f = idx - CGFloat(lo)
    func comps(_ c: CGColor) -> [CGFloat] { (c.converted(to: cs, intent: .defaultIntent, options: nil) ?? c).components! }
    let c0 = comps(ringColors[lo]), c1 = comps(ringColors[hi])
    ctx.setFillColor(color(c0[0] + (c1[0] - c0[0]) * f, c0[1] + (c1[1] - c0[1]) * f, c0[2] + (c1[2] - c0[2]) * f))
    ctx.move(to: center)
    ctx.addArc(center: center, radius: 340, startAngle: a0, endAngle: a1, clockwise: false)
    ctx.closePath()
    ctx.fillPath()
}
_ = ring
ctx.restoreGState()

// Darken the ring's middle so it reads as a ring, not a disc.
let hole = CGGradient(colorsSpace: cs, colors: [color(0.06, 0.05, 0.11, 1), color(0.06, 0.05, 0.11, 0.85),
                                                color(0.06, 0.05, 0.11, 0)] as CFArray,
                      locations: [0, 0.62, 1])!
ctx.drawRadialGradient(hole, startCenter: center, startRadius: 0, endCenter: center, endRadius: 330, options: [])

// Keycap: frosted, translucent white, overlapping the ring.
let capOuter = CGRect(x: 332, y: 337, width: 360, height: 350)
let capPath = CGPath(roundedRect: capOuter, cornerWidth: 70, cornerHeight: 70, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: color(0, 0, 0, 0.45))
ctx.addPath(capPath)
ctx.setFillColor(color(1, 1, 1, 0.22))
ctx.fillPath()
ctx.restoreGState()

// Keycap top face (dished), slightly brighter.
let capTop = CGRect(x: 368, y: 400, width: 288, height: 260)
let topPath = CGPath(roundedRect: capTop, cornerWidth: 52, cornerHeight: 52, transform: nil)
ctx.saveGState()
ctx.addPath(topPath)
ctx.clip()
let face = CGGradient(colorsSpace: cs, colors: [color(1, 1, 1, 0.55), color(1, 1, 1, 0.28)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(face, start: CGPoint(x: 512, y: 660), end: CGPoint(x: 512, y: 400), options: [])
ctx.restoreGState()

// Crisp edges.
ctx.addPath(capPath)
ctx.setStrokeColor(color(1, 1, 1, 0.55))
ctx.setLineWidth(6)
ctx.strokePath()
ctx.addPath(topPath)
ctx.setStrokeColor(color(1, 1, 1, 0.4))
ctx.setLineWidth(4)
ctx.strokePath()

ctx.restoreGState()

// Inner hairline on the body.
ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 2, dy: 2), cornerWidth: 183, cornerHeight: 183, transform: nil))
ctx.setStrokeColor(color(1, 1, 1, 0.10))
ctx.setLineWidth(4)
ctx.strokePath()

guard let image = ctx.makeImage(),
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { exit(1) }
try! data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
