import AppKit
@main struct SettingsWindowSmoke {
 @MainActor static func main() {
  let app=NSApplication.shared;app.setActivationPolicy(.prohibited)
  let settings=NSWindow(contentRect:NSRect(x:100,y:100,width:200,height:100),styleMask:.titled,backing:.buffered,defer:false)
  let panel=NSPanel(contentRect:NSRect(x:100,y:100,width:100,height:60),styleMask:.nonactivatingPanel,backing:.buffered,defer:false)
  settings.isReleasedWhenClosed=false;panel.isReleasedWhenClosed=false
  settings.identifier=NSUserInterfaceItemIdentifier("com.apple.SwiftUI.Settings")
  panel.identifier=NSUserInterfaceItemIdentifier("UniversalMac.StatusPanel")
  settings.orderFront(nil);panel.orderFront(nil)
  precondition(settings.isVisible && panel.isVisible)
  precondition(SelectionBridge.dismissStatusPanels([settings,panel],keyWindow:panel))
  precondition(settings.isVisible,"Settings must remain visible when dismissing the status panel")
  precondition(!panel.isVisible,"Only the transient panel should be dismissed")
  precondition(!SelectionBridge.dismissStatusPanels([settings],keyWindow:settings))
  precondition(settings.isVisible,"Fn from Settings must keep Settings visible")
  settings.close();panel.close()
  print("PASS: status panel dismissed; Settings stays visible; Settings focus does not request app switching")
 }
}
