import AppKit

// Finder positions use a 640 × 360 point canvas; render at Retina resolution.
let image = NSImage(size: NSSize(width: 640, height: 360))
image.lockFocus()
NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 640, height: 360).fill()
func label(_ text: String, y: CGFloat, size: CGFloat, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color
    ]
    let width = (text as NSString).size(withAttributes: attributes).width
    (text as NSString).draw(at: NSPoint(x: (640 - width) / 2, y: y), withAttributes: attributes)
}
label("MiniVoice", y: 294, size: 26, color: .darkGray)
label("将 MiniVoice 拖入 Applications 文件夹安装", y: 48, size: 17, color: .gray)
label("→", y: 159, size: 44, color: NSColor(calibratedRed: 0, green: 0.65, blue: 0.47, alpha: 1))
image.unlockFocus()
guard CommandLine.arguments.count == 2,
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("无法生成 DMG 背景")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
