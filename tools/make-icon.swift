// Usage: swift tools/make-icon.swift  -> writes Resources/AppIcon.icns
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let r = NSRect(x: s * 0.05, y: s * 0.05, width: s * 0.9, height: s * 0.9)  // macOS icon grid margin
    let bg = NSBezierPath(roundedRect: r, xRadius: s * 0.2, yRadius: s * 0.2)
    NSGradient(starting: NSColor(red: 0.16, green: 0.20, blue: 0.32, alpha: 1), ending: NSColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1))!.draw(in: bg, angle: -90)
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.5, weight: .regular).applying(.init(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "display", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let sz = sym.size
        sym.draw(in: NSRect(x: (s - sz.width) / 2, y: (s - sz.height) / 2, width: sz.width, height: sz.height))
    }
    // palette tint paints the whole symbol white; refill the screen area so it reads as a display
    let screen = NSBezierPath(roundedRect: NSRect(x: s * 0.255, y: s * 0.385, width: s * 0.49, height: s * 0.315), xRadius: s * 0.02, yRadius: s * 0.02)
    NSGradient(starting: NSColor(red: 0.20, green: 0.75, blue: 0.85, alpha: 1), ending: NSColor(red: 0.25, green: 0.35, blue: 0.95, alpha: 1))!.draw(in: screen, angle: -45)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let set = NSTemporaryDirectory() + "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: set)
try! FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base)@2x.png"))
}
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set, "-o", "Resources/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
