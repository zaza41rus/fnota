import SwiftUI
import AppKit
struct AppMenu:View {
 @Bindable var state:AppState
 @Environment(\.openSettings) private var openSettings
 @Environment(\.colorScheme) private var colorScheme
 @State private var choosingTime=false
 @State private var choosingApplication=false
 @State private var minutes=30
 @State private var panelHeight:CGFloat=280
 private var optionFont:Font { .system(size:14,weight:.regular) }
 private var secondaryFont:Font { .system(size:13,weight:.regular) }
 var body:some View {
  VStack(spacing:0) {
   HStack {
    VStack(alignment:.leading,spacing:3) {
     Text("Keep macOS awake")
     Text("Prevents your Mac from going to sleep.").font(secondaryFont).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
    }.frame(maxWidth:.infinity,alignment:.leading)
    Toggle("Keep macOS awake",isOn:Binding(get:{state.sleep.enabled},set:{ enabled in
     setAwake(enabled)
    })).labelsHidden().toggleStyle(.switch).fixedSize()
   }.padding(.vertical,10).disabled(!state.sleep.closedLid.installed).opacity(state.sleep.closedLid.installed ? 1 : 0.45)
   if state.sleep.enabled {
   HStack {
    Text("Application").font(optionFont)
    Spacer()
    Button { state.sleep.refreshRunningApplications();choosingApplication=true } label: {
     HStack(spacing:8) {
      Text(state.sleep.applicationID.isEmpty ? L("Any") : state.sleep.applicationName).lineLimit(1).truncationMode(.middle)
      Image(systemName:"chevron.down").font(.system(size:10,weight:.medium)).foregroundStyle(.secondary)
     }.padding(.horizontal,12).frame(minWidth:66,maxWidth:180,minHeight:28,maxHeight:28)
      .background(Color.primary.opacity(0.07),in:RoundedRectangle(cornerRadius:6,style:.continuous))
    }.buttonStyle(.plain).fixedSize()
     .popover(isPresented:$choosingApplication) {
      VStack(alignment:.leading,spacing:4) {
       Button("Any") { state.sleep.clearApplication();choosingApplication=false }
       Divider()
       ScrollView {
        VStack(alignment:.leading,spacing:4) {
         ForEach(state.sleep.runningApplications) { application in
          Button { state.sleep.selectApplication(application);choosingApplication=false } label: {
           Text(application.name).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,4)
          }.buttonStyle(.plain)
         }
        }
       }.frame(maxHeight:260)
      }.padding(12).frame(width:220)
     }

   }.padding(.vertical,9).padding(.leading,12)
   HStack {
    Text("Time")
    Spacer()
    Button {
     minutes=state.sleep.durationStep>=121 ? 30 : max(1,Int(state.sleep.durationStep))
     choosingTime=true
    } label: {
     HStack(spacing:8) {
      if state.sleep.durationStep>=121 {
       Image(systemName:"infinity").font(.system(size:14,weight:.regular))
      } else {
       Text(state.sleep.countdownLabel).monospacedDigit()
      }
      Image(systemName:"chevron.down").font(.system(size:10,weight:.medium)).foregroundStyle(.secondary)
     }.padding(.horizontal,12).frame(minWidth:66,minHeight:28,maxHeight:28)
      .background(Color.primary.opacity(0.07),in:RoundedRectangle(cornerRadius:6,style:.continuous))
    }.buttonStyle(.plain).help("Choose duration").accessibilityLabel(Text("Choose duration"))
     .popover(isPresented:$choosingTime) {
      VStack(alignment:.leading,spacing:14) {
       Text("Duration").font(.headline)
       Stepper(value:$minutes,in:1...120) {
        HStack { Text("Minutes");TextField("Minutes",value:$minutes,format:.number).frame(width:55).textFieldStyle(.roundedBorder) }
       }
       HStack {
        Button("Unlimited") { state.sleep.setTimedDuration(121);choosingTime=false }
        Spacer()
        Button("Start timer") { state.sleep.setTimedDuration(Double(min(120,max(1,minutes))));choosingTime=false }.buttonStyle(.borderedProminent)
       }
      }.padding(16).frame(width:250)
     }
   }.padding(.vertical,8).padding(.leading,12)
   Divider().padding(.top,8)
   }
   feature(voice:true)
   feature(voice:false)
   HStack {
    VStack(alignment:.leading,spacing:3) {
     Text("Keyboard layout")
     Text("Corrects a recognized word after Space. Press Esc immediately to undo.")
      .font(secondaryFont).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
    }.frame(maxWidth:.infinity,alignment:.leading)
    Toggle("Automatically switch keyboard layouts",isOn:$state.autoSwitchKeyboardLayout)
     .labelsHidden().toggleStyle(.switch).fixedSize()
   }.padding(.vertical,10)
   Button { showWindow("permissions") } label: {
    HStack {
     Text("Settings")
     Spacer()
     if permissionsMissing { Image(systemName:"exclamationmark.shield").foregroundStyle(.red) }
     Image(systemName:"chevron.right").foregroundStyle(.tertiary)
    }.frame(maxWidth:.infinity,minHeight:42).contentShape(Rectangle())
   }.buttonStyle(MenuRowButtonStyle()).padding(.top,2)
   Button { NSApp.terminate(nil) } label: {
    Text("Quit").foregroundStyle(Color.accentColor).frame(maxWidth:.infinity).padding(.vertical,10).contentShape(Rectangle())
   }.buttonStyle(MenuRowButtonStyle())
  }.padding(.horizontal,16).padding(.vertical,6).frame(width:320)
   .font(optionFont).controlSize(.regular)
   .disclosureGroupStyle(MenuDisclosureStyle())
   .fixedSize(horizontal:false,vertical:true)
   .onGeometryChange(for:CGFloat.self,of:{$0.size.height}) { panelHeight=$0 }
   .background(StatusPanelMarker(preferredHeight:panelHeight,preferredWidth:320).frame(width:0,height:0))
   .onAppear { state.sleep.refreshRunningApplications();state.translationModels.refreshInstalled();state.refreshSystemState() }
   .onReceive(NSWorkspace.shared.notificationCenter.publisher(for:NSWorkspace.didLaunchApplicationNotification)) { _ in state.sleep.refreshRunningApplications() }
   .onReceive(NSWorkspace.shared.notificationCenter.publisher(for:NSWorkspace.didTerminateApplicationNotification)) { _ in state.sleep.refreshRunningApplications() }
 }
 private func setAwake(_ enabled:Bool) {
  if enabled { state.sleep.clearApplication();state.sleep.setDuration(121) } else { state.sleep.stop() }
 }
 private var permissionsMissing:Bool {
  state.permissions.issues.contains { $0.id == "microphone" || $0.id == "accessibility" }
   || !state.sleep.closedLid.installed
 }
 private func showWindow(_ page:String) {
  state.settingsPage=page
  _ = SelectionBridge.dismissStatusPanels(NSApp.windows,keyWindow:NSApp.keyWindow)
  NSApp.activate(ignoringOtherApps:true);openSettings()
 }
 private func keyHint(_ text:String) -> Text {
  guard let range=text.range(of:"fn") else { return Text(text) }
  return Text(String(text[..<range.lowerBound])) + Text("[").foregroundStyle(.secondary) + Text("fn").fontWeight(.bold).foregroundStyle(.primary) + Text("]").foregroundStyle(.secondary) + Text(String(text[range.upperBound...]))
 }
 private func feature(voice:Bool) -> some View {
  let hasModel=voice ? state.voiceEnabled : state.translationEnabled
  let relevantIssue=state.permissions.issues.contains { issue in
   if issue.id=="accessibility" { return true }
   if voice { return issue.id=="microphone" }
   return issue.id==NSWorkspace.shared.frontmostApplication?.bundleIdentifier
  }
  let ready=hasModel && !relevantIssue
  let hint=voice ? L("Hold fn to dictate text in any application.") : L("Double-press fn to translate a page or selected text in your browser.")
  return VStack(alignment:.leading,spacing:3) {
   Text(voice ? "Dictation" : "Browser translation").foregroundStyle(ready ? Color.primary : Color.secondary)
   keyHint(hint).font(secondaryFont).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
  }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,12).opacity(ready ? 1 : 0.6)
 }
}
