import AppKit
@main struct MenuPanelSizingSmoke {
 @MainActor static func main() {
  _=NSApplication.shared;NSApp.setActivationPolicy(.prohibited)
  let panel=NSWindow(contentRect:NSRect(x:100,y:400,width:340,height:180),styleMask:.borderless,backing:.buffered,defer:false)
  let unrelated=NSWindow(contentRect:NSRect(x:500,y:400,width:340,height:180),styleMask:.borderless,backing:.buffered,defer:false)
  let marker=StatusPanelMarkerView();panel.contentView?.addSubview(marker)
  let top=panel.frame.maxY
  marker.preferredHeight=420;marker.markWindow()
  RunLoop.main.run(until:Date().addingTimeInterval(0.1))
  precondition(abs(panel.frame.height-420)<1 && abs(panel.frame.maxY-top)<1)
  precondition(unrelated.frame.height==180)
  marker.preferredHeight=160;marker.markWindow()
  RunLoop.main.run(until:Date().addingTimeInterval(0.1))
  precondition(abs(panel.frame.height-160)<1 && abs(panel.frame.maxY-top)<1)
  print("PASS: native menu grows and shrinks, preserves top edge, leaves other windows unchanged")
 }
}
