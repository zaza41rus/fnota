import AppKit
let args=CommandLine.arguments
guard let image=NSImage(contentsOfFile:args[1]),NSWorkspace.shared.setIcon(image,forFile:args[2],options:[]) else { fatalError("Cannot set installer icon") }
