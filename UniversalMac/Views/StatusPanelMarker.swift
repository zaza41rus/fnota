import SwiftUI
import AppKit
// Mark and size only our menu panel; dictation must never dismiss another window.
struct StatusPanelMarker:NSViewRepresentable {
 var preferredHeight:CGFloat?=nil
 var preferredWidth:CGFloat?=nil
 func makeNSView(context:Context)->StatusPanelMarkerView {
  let view=StatusPanelMarkerView();view.preferredHeight=preferredHeight;view.preferredWidth=preferredWidth;return view
 }
 func updateNSView(_ view:StatusPanelMarkerView,context:Context) { view.preferredHeight=preferredHeight;view.preferredWidth=preferredWidth;view.markWindow() }
}
final class StatusPanelMarkerView:NSView {
 var preferredHeight:CGFloat?
 var preferredWidth:CGFloat?
 override func viewDidMoveToWindow() { super.viewDidMoveToWindow();markWindow() }
 func markWindow() {
  window?.identifier=NSUserInterfaceItemIdentifier("UniversalMac.StatusPanel")
  // MenuBarExtra can retain its initial window height after SwiftUI content expands.
  // Resize the public AppKit window, preserving its top edge below the status icon.
  DispatchQueue.main.async { [weak self] in
   guard let self,let window=self.window,let height=self.preferredHeight,height.isFinite,height>0 else { return }
   let content=NSSize(width:self.preferredWidth ?? window.contentView?.bounds.width ?? 340,height:ceil(height))
   var frame=window.frameRect(forContentRect:NSRect(origin:.zero,size:content))
   guard abs(window.frame.height-frame.height)>1 else { return }
   frame.origin=NSPoint(x:window.frame.maxX-frame.width,y:window.frame.maxY-frame.height)
   if let screen=window.screen { frame=window.constrainFrameRect(frame,to:screen) }
   window.setFrame(frame,display:true)
  }
 }
}
