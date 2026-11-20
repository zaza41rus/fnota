import SwiftUI
import AppKit
struct ContentView:View {
 @Bindable var state:AppState
 @State private var back:[String]=[]
 @State private var forward:[String]=[]
 @State private var navigating=false
 private let pages=["speech","translation","keyboard","about","permissions"]
 private var selection:Binding<String?> { Binding(get:{ pages.contains(state.settingsPage) ? state.settingsPage : "speech" },set:{ if let value=$0 { state.settingsPage=value } }) }
 private var title:LocalizedStringKey {
  switch state.settingsPage { case "translation":"Browser translation";case "keyboard":"Keyboard layout";case "about":"About fnota";case "permissions":"Permissions";default:"Dictation" }
 }
 var body:some View {
  NavigationSplitView(columnVisibility:.constant(.all)) {
   List {
    HStack(spacing:10) {
     Image(nsImage:NSImage(named:NSImage.applicationIconName)!).resizable().frame(width:32,height:32)
     VStack(alignment:.leading,spacing:2) {
      Text("fnota").font(.headline).foregroundStyle(.primary)
      (Text("Version") + Text(" " + (Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.1.0"))).foregroundStyle(.secondary)
     }.font(.caption)
    }.padding(.vertical,12).selectionDisabled()
    Section("Features") {
     sidebarRow("Dictation",icon:"mic",page:"speech")
     sidebarRow("Browser translation",icon:"character.bubble",page:"translation")
     sidebarRow("Keyboard layout",icon:"keyboard",page:"keyboard")
    }
    Section("More") {
     sidebarRow("About fnota",icon:"info.circle",page:"about")
     sidebarRow("Permissions",icon:"checkmark.shield",page:"permissions")
    }
   }.listStyle(.sidebar).toolbar(removing:.sidebarToggle).navigationSplitViewColumnWidth(min:200,ideal:230,max:280)
  } detail: {
   Group {
    switch state.settingsPage {
    case "translation":TranslationSettingsView(state:state)
    case "keyboard":KeyboardLayoutSettingsView(state:state)
    case "about":AboutSettingsView(state:state)
    case "permissions":PermissionsSettingsView(state:state)
    default:SpeechSettingsView(state:state)
    }
   }.navigationTitle("").toolbarRole(.editor)
    .toolbar {
     ToolbarItem(placement:.navigation) {
      SettingsNavigationControl(canGoBack:!back.isEmpty,canGoForward:!forward.isEmpty,goBack:{navigate(backward:true)},goForward:{navigate(backward:false)})
     }
     ToolbarItem(placement:.navigation) { Text(title).font(.headline) }.sharedBackgroundVisibility(.hidden)
    }
  }.navigationSplitViewStyle(.balanced).toolbar(removing:.sidebarToggle)
   .background(SettingsWindowStyle().frame(width:0,height:0))
   .frame(minWidth:820,idealWidth:900,minHeight:560,idealHeight:650)
   .onAppear { state.refreshSystemState();state.translationModels.refreshInstalled() }
   .onChange(of:state.voiceEnabled) { state.refreshSystemState() }
   .onChange(of:state.translationEnabled) { state.refreshSystemState() }
   .onChange(of:state.settingsPage) { old,new in
    if navigating { navigating=false }
    else if old != new { back.append(old);forward=[] }
   }
 }
 private func sidebarRow(_ title:LocalizedStringKey,icon:String,page:String) -> some View {
  Button { state.settingsPage=page } label: {
   HStack(spacing:10) {
    Image(systemName:icon).foregroundStyle(Color.accentColor).frame(width:20)
    Text(title).foregroundStyle(.primary)
    Spacer(minLength:0)
   }.padding(.horizontal,18).padding(.vertical,6).contentShape(Rectangle())
  }.buttonStyle(.plain)
   .listRowInsets(EdgeInsets(top:0,leading:0,bottom:0,trailing:0))
   .listRowBackground(
    RoundedRectangle(cornerRadius:8)
     .fill(state.settingsPage==page ? Color.primary.opacity(0.08) : Color.clear)
     .padding(.horizontal,10)
   )
   .accessibilityAddTraits(state.settingsPage==page ? .isSelected : [])
 }
 private func navigate(backward:Bool) {
  if backward,let page=back.popLast() { forward.append(state.settingsPage);navigating=true;state.settingsPage=page }
  else if !backward,let page=forward.popLast() { back.append(state.settingsPage);navigating=true;state.settingsPage=page }
 }
}
