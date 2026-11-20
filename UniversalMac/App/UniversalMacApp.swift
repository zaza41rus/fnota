import SwiftUI
import AppKit
@MainActor final class AppDelegate:NSObject,NSApplicationDelegate {
 var state:AppState?
 func applicationDidFinishLaunching(_ notification:Notification) { NSApp.setActivationPolicy(.accessory); state?.startServices()
  if CommandLine.arguments.contains("--setup-closed-lid"),let state {
   NSApp.activate(ignoringOtherApps:true)
   state.sleep.closedLid.setEnabled(true,awake:state.sleep.enabled)
  }
 }
 func applicationWillTerminate(_ notification:Notification) { state?.audio.restoreOutput(); state?.sleep.stop(preservePreference:true); state?.shortcuts.unregister(); state?.keyboardLayoutSwitcher.stop() }
}
@main struct UniversalMacApp:App {
 @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
 private let state:AppState
 init() { let value=AppState();state=value;delegate.state=value }
 var body:some Scene {
  MenuBarExtra {
   AppMenu(state:state).environment(\.locale,Locale(identifier:state.uiLanguage))
  } label: { StatusIconView(state:state) }.menuBarExtraStyle(.window)
  Settings { ContentView(state:state).environment(\.locale,Locale(identifier:state.uiLanguage)) }.defaultSize(width:900,height:650).windowResizability(.contentMinSize).windowToolbarStyle(.unified)
 }
}


private struct StatusIconView:View {
 let state:AppState
 @Environment(\.openSettings) private var openSettings
 var body:some View {
  statusImage
   .accessibilityLabel(state.sleep.enabled ? Text("Keep macOS awake") : Text("fnota"))
   .onAppear {
   if let index=CommandLine.arguments.firstIndex(of:"--show-settings") {
    if CommandLine.arguments.count>index+1 { state.settingsPage=CommandLine.arguments[index+1] }
    NSApp.activate(ignoringOtherApps:true);openSettings()
   }
  }
 }

 private var statusImage:Image {
  guard state.sleep.enabled,
        let original = NSImage(systemSymbolName:"fn",accessibilityDescription:nil),
        let symbol = original.withSymbolConfiguration(
         NSImage.SymbolConfiguration(pointSize:15,weight:.regular)
          .applying(.init(paletteColors:[.labelColor]))
        )
  else { return Image(systemName:"fn") }

  let dotDiameter:CGFloat = 5
  let gap:CGFloat = 5
  let height = max(16,symbol.size.height)
  let icon = NSImage(size:NSSize(width:dotDiameter+gap+symbol.size.width,height:height),flipped:false) { rect in
   NSColor(srgbRed:243/255,green:140/255,blue:238/255,alpha:1).setFill()
   NSBezierPath(ovalIn:NSRect(x:0,y:(rect.height-dotDiameter)/2,width:dotDiameter,height:dotDiameter)).fill()
   symbol.draw(at:NSPoint(x:dotDiameter+gap,y:(rect.height-symbol.size.height)/2),from:.zero,operation:.sourceOver,fraction:1)
   return true
  }
  return Image(nsImage:icon).renderingMode(.original)
 }

}
