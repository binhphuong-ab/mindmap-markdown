// Draws the Mindmap Markdown app icon into an .iconset folder: swift tools/make-icon.swift <out.iconset>
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func draw(_ s: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let k = s / 1024
    // macOS icon grid: 824pt squircle centred in 1024.
    let body = NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185 * k, yRadius: 185 * k)
    NSGradient(colors: [color(0xFFFFFF), color(0xE9EAFB)])!.draw(in: squircle, angle: -90)

    let center = NSPoint(x: 512 * k, y: 512 * k)
    let leaves: [(NSPoint, UInt32)] = [
        (NSPoint(x: 790, y: 720), 0xF25F5C), (NSPoint(x: 820, y: 512), 0xF79F1F),
        (NSPoint(x: 790, y: 304), 0x2EC4B6), (NSPoint(x: 234, y: 304), 0x3A86FF),
        (NSPoint(x: 204, y: 512), 0x8338EC), (NSPoint(x: 234, y: 720), 0xFF4D8D),
    ]
    for (p, hex) in leaves {
        let end = NSPoint(x: p.x * k, y: p.y * k)
        let midX = (center.x + end.x) / 2
        let path = NSBezierPath()
        path.move(to: center)
        path.curve(to: end, controlPoint1: NSPoint(x: midX, y: center.y), controlPoint2: NSPoint(x: midX, y: end.y))
        path.lineWidth = 30 * k
        path.lineCapStyle = .round
        color(hex).setStroke()
        path.stroke()
        let dot = NSBezierPath(ovalIn: NSRect(x: end.x - 46 * k, y: end.y - 46 * k, width: 92 * k, height: 92 * k))
        color(hex).setFill()
        dot.fill()
    }
    let rootRect = NSRect(x: 352 * k, y: 442 * k, width: 320 * k, height: 140 * k)
    let root = NSBezierPath(roundedRect: rootRect, xRadius: 70 * k, yRadius: 70 * k)
    let shadow = NSShadow()
    shadow.shadowColor = color(0x6D5DFC, 0.45); shadow.shadowBlurRadius = 30 * k
    shadow.shadowOffset = NSSize(width: 0, height: -10 * k)
    NSGraphicsContext.saveGraphicsState(); shadow.set()
    NSGradient(colors: [color(0x6D5DFC), color(0xB04BF2)])!.draw(in: root, angle: -30)
    NSGraphicsContext.restoreGraphicsState()
    // "M↓" mark on the root pill, a nod to Markdown.
    let text = NSAttributedString(string: "M↓", attributes: [
        .font: NSFont.systemFont(ofSize: 92 * k, weight: .heavy), .foregroundColor: NSColor.white])
    let ts = text.size()
    text.draw(at: NSPoint(x: rootRect.midX - ts.width / 2, y: rootRect.midY - ts.height / 2))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = CGFloat(base * scale)
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! draw(px).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
    }
}
