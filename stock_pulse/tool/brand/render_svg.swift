// Rasterises brand SVGs with AppKit. Reads jobs from stdin, one per line:
//   <source.svg> <destination.png> <pixels> <alpha|opaque|light>
// `opaque` flattens on #0E1116 and drops the alpha channel (iOS rejects alpha);
// `light` swaps the dark accent for the light-theme accent before rendering.
import AppKit
import Foundation

let darkAccent = "#5AA9FF"
let lightAccent = "#0B5CAD"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("render_svg: \(message)\n".data(using: .utf8)!)
    exit(1)
}

func rgba(_ image: NSImage, _ size: Int, opaque: Bool) -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fail("no bitmap context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    if opaque {
        NSColor(srgbRed: 14 / 255, green: 17 / 255, blue: 22 / 255, alpha: 1).setFill()
        rect.fill()
    }
    image.draw(in: rect)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func dropAlpha(_ bitmap: NSBitmapImageRep, _ size: Int) -> NSBitmapImageRep {
    guard let rgb = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 24),
        let source = bitmap.bitmapData, let target = rgb.bitmapData else { fail("no rgb bitmap") }
    for y in 0..<size {
        for x in 0..<size {
            for c in 0..<3 {
                target[y * rgb.bytesPerRow + x * 3 + c] = source[y * bitmap.bytesPerRow + x * 4 + c]
            }
        }
    }
    return rgb
}

func render(source: String, destination: String, size: Int, mode: String) {
    guard var svg = try? String(contentsOfFile: source, encoding: .utf8) else { fail("cannot read \(source)") }
    if mode == "light" { svg = svg.replacingOccurrences(of: darkAccent, with: lightAccent) }
    guard let image = NSImage(data: svg.data(using: .utf8)!) else { fail("cannot parse \(source)") }
    let opaque = mode == "opaque"
    let bitmap = rgba(image, size, opaque: opaque)
    let output = opaque ? dropAlpha(bitmap, size) : bitmap
    guard let png = output.representation(using: .png, properties: [.interlaced: false]) else {
        fail("cannot encode \(destination)")
    }
    let url = URL(fileURLWithPath: destination)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    do { try png.write(to: url) } catch { fail("cannot write \(destination)") }
}

while let line = readLine() {
    let parts = line.split(separator: " ").map(String.init)
    if parts.isEmpty { continue }
    guard parts.count == 4, let size = Int(parts[2]), ["alpha", "opaque", "light"].contains(parts[3]) else {
        fail("bad job: \(line)")
    }
    render(source: parts[0], destination: parts[1], size: size, mode: parts[3])
}
