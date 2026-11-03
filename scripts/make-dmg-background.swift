// Usage: swift scripts/make-dmg-background.swift  -> writes Config/dmg/background.png (727x626 pt @2x)
import AppKit

let w = 727.0, h = 626.0, scale = 2.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * scale), pixelsHigh: Int(h * scale), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: w, height: h)  // 144 dpi, so Finder shows it at 727x626 pt
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSGradient(starting: NSColor(red: 0.93, green: 0.95, blue: 0.99, alpha: 1), ending: NSColor(red: 0.80, green: 0.86, blue: 0.96, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, y: CGFloat, alpha: CGFloat) {
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                           .foregroundColor: NSColor(red: 0.10, green: 0.15, blue: 0.30, alpha: alpha)]
    let sz = (s as NSString).size(withAttributes: a)
    (s as NSString).draw(at: NSPoint(x: (w - sz.width) / 2, y: h - y - sz.height), withAttributes: a)
}
text("Drag Second Display to Applications", size: 20, weight: .semibold, y: 28, alpha: 1)
text("Blocked on first launch? Open “Read Me First.txt”", size: 13, weight: .regular, y: 330, alpha: 0.65)

// arrow between the two icons (icon centres at x=198 and x=529, y=195 from top)
let ay = h - 195
let arrow = NSBezierPath()
arrow.lineWidth = 6; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 290, y: ay)); arrow.line(to: NSPoint(x: 430, y: ay))
arrow.move(to: NSPoint(x: 405, y: ay + 22)); arrow.line(to: NSPoint(x: 432, y: ay)); arrow.line(to: NSPoint(x: 405, y: ay - 22))
NSColor(red: 0.25, green: 0.35, blue: 0.95, alpha: 0.8).setStroke()
arrow.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Config/dmg/background.png"))
