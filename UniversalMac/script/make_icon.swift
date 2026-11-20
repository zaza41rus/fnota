// Usage: swift make_icon.swift /path/to/Resources
// AppIcon.svg is the source. The menu bar uses its own glyph.
import AppKit

let resources = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let source = resources.appendingPathComponent("AppIcon-preview.png")
let artworkURL = resources.appendingPathComponent("AppIcon.svg")
// Preserve the SVG source. The system icon renderer needs opaque foreground
// pixels, so bake the artwork's translucent black into an opaque gray.
let svg = try String(contentsOf: artworkURL, encoding: .utf8)
let systemArtwork = svg
    .replacingOccurrences(of: #"<g opacity="0.5">"#, with: "<g>")
    .replacingOccurrences(of: #"fill="black" fill-opacity="0.85""#, with: ##"fill="#818181""##)
guard let artwork = NSImage(data: Data(systemArtwork.utf8)) else {
    throw CocoaError(.fileReadCorruptFile)
}
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
artwork.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: source)

let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func run(_ path: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: path, code: Int(process.terminationStatus))
    }
}

for pointSize in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = String(pointSize * scale)
        let suffix = scale == 2 ? "@2x" : ""
        let filename = "icon_\(pointSize)x\(pointSize)\(suffix).png"
        let output = iconset.appendingPathComponent(filename)
        try run("/usr/bin/sips", ["-z", pixels, pixels, source.path, "--out", output.path])
    }
}

try run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o",
                             resources.appendingPathComponent("AppIcon.icns").path])
