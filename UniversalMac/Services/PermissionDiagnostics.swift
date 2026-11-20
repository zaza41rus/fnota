import AppKit
import AVFoundation
import ApplicationServices
import Carbon

@MainActor @Observable final class PermissionDiagnostics {
 struct Issue:Identifiable { let id:String;let message:String }
 private var problems:[String:String]=[:]
 var issues:[Issue] { problems.keys.sorted().map { Issue(id:$0,message:problems[$0]!) } }
 var busy=false
 private var task:Task<Void,Never>?
 private var waitingFor:String?
 private var lastProbe:Date = .distantPast
 private var lastProcesses:Set<Int32>=[]
 private let browsers=[("com.google.Chrome","Google Chrome"),("com.apple.Safari","Safari")]
 nonisolated static func missing(voice:Bool,translation:Bool,microphone:Bool,accessibility:Bool) -> Set<String> {
  var result=Set<String>()
  if voice && !microphone { result.insert("microphone") }
  if (voice || translation) && !accessibility { result.insert("accessibility") }
  return result
 }
 nonisolated private static func automation(_ id:String,request:Bool) -> OSStatus {
  var target=AEDesc()
  let data=Array(id.utf8)
  let created=data.withUnsafeBytes { AECreateDesc(DescType(typeApplicationBundleID),$0.baseAddress,$0.count,&target) }
  guard created==noErr else { return OSStatus(created) }
  defer { AEDisposeDesc(&target) }
  return AEDeterminePermissionToAutomateTarget(&target,AEEventClass(typeWildCard),AEEventID(typeWildCard),request)
 }
 private func runningBrowsers() -> [(String,String)] {
  let running=Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
  return browsers.filter { running.contains($0.0) }
 }
 func refresh(voice:Bool,translation:Bool,force:Bool=false) {
  let missing=Self.missing(voice:voice,translation:translation,microphone:AVCaptureDevice.authorizationStatus(for:.audio) == .authorized,accessibility:AXIsProcessTrusted())
  problems["microphone"]=missing.contains("microphone") ? L("Microphone access is needed for dictation.") : nil
  problems["accessibility"]=missing.contains("accessibility") ? L("Accessibility access is needed for shortcuts and text insertion.") : nil
  let live=translation ? runningBrowsers() : []
  for (id,_) in browsers where !live.contains(where:{$0.0==id}) { problems[id]=nil }
  if let waitingFor,!missing.contains(waitingFor),!busy {
   self.waitingFor=nil;runSetup(voice:voice,translation:translation);return
  }
  guard !busy,!live.isEmpty else { return }
  let processes=Set(NSWorkspace.shared.runningApplications.filter { app in live.contains(where:{$0.0==app.bundleIdentifier}) }.map(\.processIdentifier))
  guard force || processes != lastProcesses || Date().timeIntervalSince(lastProbe)>30 || live.contains(where:{problems[$0.0] != nil}) else { return }
  lastProcesses=processes;lastProbe=Date()
  busy=true
  task=Task {
   defer { busy=false }
   for (id,name) in live {
    if Self.automation(id,request:false)==noErr { probe(id:id,name:name) }
    else { problems[id]="\(name): \(L("Browser automation permission is needed."))" }
    await Task.yield()
   }
  }
 }
 private func probe(id:String,name:String) {
  do { try BrowserTranslation().checkAccess(browserName:name);problems[id]=nil }
  catch { problems[id]=error.localizedDescription }
 }
 func runSetup(voice:Bool,translation:Bool) {
  guard !busy else { return };busy=true
  task=Task {
   defer { busy=false }
   if voice,AVCaptureDevice.authorizationStatus(for:.audio) == .notDetermined {
    _ = await AVCaptureDevice.requestAccess(for:.audio)
   }
   if voice,AVCaptureDevice.authorizationStatus(for:.audio) != .authorized {
    problems["microphone"]=L("Allow microphone access for UniversalMac in macOS Settings, then return here.")
    waitingFor="microphone"
    NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
    return
   }
   problems["microphone"]=nil
   if (voice || translation),!AXIsProcessTrusted() {
    problems["accessibility"]=L("Allow UniversalMac in Accessibility / Device Control and Data Access, then return here.")
    waitingFor="accessibility"
    AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt":true] as CFDictionary)
    NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    return
   }
   problems["accessibility"]=nil
   var automationDenied=false
   if translation {
    for (id,name) in runningBrowsers() {
     if Self.automation(id,request:true)==noErr { probe(id:id,name:name) }
     else { automationDenied=true;problems[id]="\(name): \(L("Allow browser automation in macOS Settings → Privacy & Security → Automation."))" }
     await Task.yield()
    }
   }
   if automationDenied { NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!) }
   lastProbe=Date();waitingFor=nil
  }
 }
}
