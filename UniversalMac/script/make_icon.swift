// Usage: swift make_icon.swift /path/to/Resources
// AppIcon-preview.png is the source for the app icon. The menu bar uses its own glyph.
import Foundation

let resources = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let source = resources.appendingPathComponent("AppIcon-preview.png")
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
