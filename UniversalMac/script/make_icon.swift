import AppKit
let resources=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
let iconset=resources.appendingPathComponent("AppIcon.iconset",isDirectory:true)
try FileManager.default.createDirectory(at:iconset,withIntermediateDirectories:true)
func glyph(_ size:CGFloat,_ background:Bool)->NSImage {
 let image=NSImage(size:NSSize(width:size,height:size));image.lockFocus()
 if background { NSColor(calibratedRed:0.18,green:0.17,blue:0.17,alpha:1).setFill();NSBezierPath(roundedRect:NSRect(x:0,y:0,width:size,height:size),xRadius:size*0.22,yRadius:size*0.22).fill() }
 let inset = background ? size*0.20 : size*0.04
 let config=NSImage.SymbolConfiguration(pointSize:size*0.6,weight:.regular).applying(.init(paletteColors:[.white]))
 let symbol=NSImage(systemSymbolName:"fn",accessibilityDescription:nil)!.withSymbolConfiguration(config)!
 let available=NSRect(x:inset,y:inset,width:size-2*inset,height:size-2*inset)
 let ratio=min(available.width/symbol.size.width,available.height/symbol.size.height)
 let w=symbol.size.width*ratio,h=symbol.size.height*ratio
 symbol.draw(in:NSRect(x:(size-w)/2,y:(size-h)/2,width:w,height:h))

 image.unlockFocus();return image
}
func save(_ image:NSImage,_ url:URL) throws { let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!;try bitmap.representation(using:.png,properties:[:])!.write(to:url) }
for point in [16,32,128,256,512] { for scale in [1,2] { let suffix=scale==2 ? "@2x":"";try save(glyph(CGFloat(point*scale),true),iconset.appendingPathComponent("icon_\(point)x\(point)\(suffix).png")) } }
try save(glyph(44,false),resources.appendingPathComponent("MenuIcon.png"))
try save(glyph(512,true),resources.appendingPathComponent("AppIcon-preview.png"))
