import SwiftUI
import AppKit
import AVFoundation
import ApplicationServices
struct PermissionsSettingsView:View {
 @Bindable var state:AppState
 @State private var setup=false
 private var microphone:Bool { AVCaptureDevice.authorizationStatus(for:.audio) == .authorized }
 private var accessibility:Bool { AXIsProcessTrusted() }
 var body:some View {
  Form {
   Section {
    Picker("Interface language",selection:$state.uiLanguage) {
     Text("English").tag("en")
     Text("Русский").tag("ru")
     Text("Español").tag("es")
    }
    Toggle("Launch at login",isOn:Binding(get:{state.loginEnabled},set:{state.login($0)})).toggleStyle(.switch)
    if state.loginNeedsApproval { Button("Approve in macOS…") { state.openLoginSettings() } }
   }

   Section {
    permissionRow("Microphone",detail:"Microphone access is needed for dictation.",allowed:microphone) {
     if AVCaptureDevice.authorizationStatus(for:.audio) == .notDetermined {
      Task { _ = await AVCaptureDevice.requestAccess(for:.audio);refresh() }
     } else { open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") }
    }
    permissionRow("Text insertion and shortcuts",detail:"Accessibility access is needed for shortcuts and text insertion.",allowed:accessibility) {
     AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt":true] as CFDictionary)
     open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }
   } header: { Text("Dictation") }
   Section {
    browserRow("Safari",id:"com.apple.Safari",instruction:"In Safari, open Safari → Settings… → Developer and turn on ‘Allow JavaScript from Apple Events’. If Developer is hidden, first enable web developer features in Safari → Settings… → Advanced. Return here and click Continue.")
    browserRow("Google Chrome",id:"com.google.Chrome",instruction:"In Chrome, open View → Developer and check ‘Allow JavaScript from Apple Events’ in the window you use for translation. Return here and click Continue.")
    Button("Open Automation settings") { open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") }
   } header: { Text("Browser translation") }
   Section {
    HStack(alignment:.top,spacing:12) {
     Image(systemName:state.sleep.closedLid.installed ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(state.sleep.closedLid.installed ? .green : .orange)
     VStack(alignment:.leading,spacing:4) {
      Text("Keep macOS awake")
      Text("The system helper enables working with the lid closed. Administrator approval is needed once.").font(.callout).foregroundStyle(.secondary)
     }.frame(maxWidth:.infinity,alignment:.leading)
     if state.sleep.closedLid.installed { Text("Installed").foregroundStyle(.secondary) }
     else { Button("Install helper") { state.sleep.closedLid.setEnabled(true,awake:state.sleep.enabled) }.disabled(state.sleep.closedLid.installing) }
    }
    if state.sleep.closedLid.installed { Button("Remove closed-lid helper…",role:.destructive) { state.sleep.stop();state.sleep.closedLid.uninstall() }.disabled(state.sleep.closedLid.installing) }
    if !state.sleep.closedLid.message.isEmpty { Text(state.sleep.closedLid.message).font(.callout).foregroundStyle(.secondary) }
   } header: { Text("System helper") }
   Section {
    HStack {
     Button("Refresh status") { refresh() }.disabled(state.permissions.busy)
     Spacer()
     Button("Configure permissions…") { setup=true;state.permissions.runSetup(voice:true,translation:true) }.buttonStyle(.borderedProminent).disabled(state.permissions.busy)
    }
    if state.permissions.busy { ProgressView("Checking permissions…") }
   }
  }.formStyle(.grouped)
   .onAppear { refresh() }
   .onReceive(NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification)) { _ in refresh() }
   .sheet(isPresented:$setup) { SetupView(state:state).padding(24).frame(width:500,height:460) }
 }
 private func refresh() { state.refreshKeyboardLayoutSwitcher();state.permissions.refresh(voice:true,translation:true,force:true) }
 private func open(_ url:String) { NSWorkspace.shared.open(URL(string:url)!) }
 private func permissionRow(_ title:LocalizedStringKey,detail:LocalizedStringKey,allowed:Bool,action:@escaping ()->Void) -> some View {
  HStack(alignment:.top,spacing:12) {
   Image(systemName:allowed ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(allowed ? .green : .orange)
   VStack(alignment:.leading,spacing:4) { Text(title);Text(detail).font(.callout).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading)
   Button(allowed ? "Manage…" : "Allow…",action:action).controlSize(.small)
  }.padding(.vertical,4)
 }
 private func browserRow(_ name:String,id:String,instruction:LocalizedStringKey) -> some View {
  let running=NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier==id }
  let issue=state.permissions.issues.first { $0.id==id }
  return VStack(alignment:.leading,spacing:8) {
   HStack {
    Label {
     Text(name).foregroundStyle(.primary)
    } icon: {
     Image(systemName:!running ? "globe" : issue == nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
      .foregroundStyle(!running ? Color.primary : issue == nil ? Color.green : Color.orange)
    }
    Spacer()
    Text(!running ? "Open browser to check" : state.permissions.busy ? "Checking permissions…" : issue == nil ? "Allowed" : "Action required").font(.callout).foregroundStyle(.secondary)
   }
   if let issue {
    Text(issue.message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
   } else if !running {
    Text(instruction).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
   }
  }.padding(.vertical,4)
 }
}
