import AppKit
import Foundation
// Export the same macOS SF Symbols used by the native views, retaining alpha
// so Chromium can tint them without approximating the paths with another set.
let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
let symbols = ["settingsGear":"gearshape", "chevronUp":"chevron.up", "person":"person.fill", "favoriteFill":"heart.fill", "styleSwitch":"arrow.triangle.2.circlepath", "clearCircle":"xmark.circle.fill", "zoomOut":"minus.magnifyingglass", "zoomIn":"plus.magnifyingglass", "previousOutline":"backward.end", "nextOutline":"forward.end", "kinetic":"textformat.size", "sidebar":"sidebar.left", "search":"magnifyingglass", "music":"music.note", "all":"music.note", "recent":"clock", "favorites":"heart", "artists":"mic", "albums":"opticaldisc", "info":"info.circle", "expand":"arrow.up.left.and.arrow.down.right", "collapse":"arrow.down.right.and.arrow.up.left", "previous":"chevron.left", "next":"chevron.right", "shuffle":"shuffle", "queue":"list.bullet", "settings":"slider.horizontal.3", "previousTrack":"backward.end.fill", "nextTrack":"forward.end.fill", "desktopLyrics":"text.bubble", "speaker":"speaker.wave.2.fill", "airplay":"airplayaudio", "play":"play.fill", "pause":"pause.fill", "sort":"arrow.up.arrow.down", "locate":"scope", "refresh":"arrow.clockwise", "checklist":"checklist", "close":"xmark", "chevronDown":"chevron.down", "repeatAll":"repeat", "repeatOne":"repeat.1", "list":"list.bullet", "single":"stop.circle", "lyrics":"text.alignleft"]
for (name,symbol) in symbols {
    guard let image = NSImage(systemSymbolName:symbol, accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:24,weight:.regular)) else { continue }
    let side=72
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:side,pixelsHigh:side,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    bitmap.size=NSSize(width:24,height:24)
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
    let size=image.size,ratio=min(22/size.width,22/size.height),rect=NSRect(x:(24-size.width*ratio)/2,y:(24-size.height*ratio)/2,width:size.width*ratio,height:size.height*ratio)
    image.draw(in:rect)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output).appendingPathComponent(name+".png"))
}
// Toolbar symbols preserve the original 15 pt medium font metrics inside
// their 28 pt hit target, rather than normalizing every symbol's ink bounds.
for (name, symbol) in ["locate":"scope", "refresh":"arrow.clockwise", "sort":"arrow.up.arrow.down", "checklist":"checklist"] {
    guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 15, weight: .medium)) else { continue }
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 84, pixelsHigh: 84, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: 28, height: 28)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: (28-image.size.width)/2, y: (28-image.size.height)/2, width: image.size.width, height: image.size.height))
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output).appendingPathComponent("toolbar-"+name+".png"))
}
// Floating wall chrome uses 22 pt medium SF Symbols in a 38 pt circle.
for (name, symbol) in ["sidebar":"sidebar.left", "search":"magnifyingglass", "settings":"slider.horizontal.3", "info":"info.circle"] {
    guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 22, weight: .medium)) else { continue }
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 114, pixelsHigh: 114, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: 38, height: 38)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: (38-image.size.width)/2, y: (38-image.size.height)/2, width: image.size.width, height: image.size.height))
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output).appendingPathComponent("wall-"+name+".png"))
}
