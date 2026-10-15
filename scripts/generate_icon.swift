import AppKit

let side = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()
NSColor(calibratedRed: 0.68, green: 0.31, blue: 0.16, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()
NSColor(calibratedRed: 1, green: 0.97, blue: 0.91, alpha: 1).setStroke()
let strokes = NSBezierPath()
strokes.lineWidth = 54
strokes.lineCapStyle = .round
for (start, end) in [
    (NSPoint(x: 512, y: 250), NSPoint(x: 512, y: 774)),
    (NSPoint(x: 250, y: 512), NSPoint(x: 774, y: 512)),
    (NSPoint(x: 326, y: 326), NSPoint(x: 698, y: 698)),
    (NSPoint(x: 326, y: 698), NSPoint(x: 698, y: 326))
] {
    strokes.move(to: start)
    strokes.line(to: end)
}
strokes.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("AppIcon.png"))
let contents = """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try contents.write(to: output.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
