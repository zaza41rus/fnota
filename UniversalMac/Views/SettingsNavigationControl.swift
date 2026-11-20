import SwiftUI
import AppKit
// Native segmented navigation provides the standard divider and disabled segments.
struct SettingsNavigationControl:NSViewRepresentable {
 let canGoBack:Bool
 let canGoForward:Bool
 let goBack:()->Void
 let goForward:()->Void
 func makeCoordinator() -> Coordinator { Coordinator(self) }
 func makeNSView(context:Context) -> NSSegmentedControl {
  let control=NSSegmentedControl(images:[NSImage(systemSymbolName:"chevron.left",accessibilityDescription:L("Back"))!,NSImage(systemSymbolName:"chevron.right",accessibilityDescription:L("Forward"))!],trackingMode:.momentary,target:context.coordinator,action:#selector(Coordinator.select(_:)))
  control.segmentStyle = .capsule
  control.controlSize = .large
  control.setWidth(32,forSegment:0);control.setWidth(32,forSegment:1)
  control.setToolTip(L("Back"),forSegment:0);control.setToolTip(L("Forward"),forSegment:1)
  return control
 }
 func updateNSView(_ control:NSSegmentedControl,context:Context) {
  context.coordinator.parent=self
  control.setEnabled(canGoBack,forSegment:0);control.setEnabled(canGoForward,forSegment:1)
 }
 final class Coordinator:NSObject {
  var parent:SettingsNavigationControl
  init(_ parent:SettingsNavigationControl) { self.parent=parent }
  @objc func select(_ sender:NSSegmentedControl) {
   if sender.selectedSegment==0 { parent.goBack() } else if sender.selectedSegment==1 { parent.goForward() }
  }
 }
}
