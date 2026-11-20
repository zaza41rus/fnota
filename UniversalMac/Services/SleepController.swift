import AppKit

import IOKit.pwr_mgt
import IOKit.ps
@MainActor @Observable final class SleepController {
 let closedLid=ClosedLidController()
 private var assertions:[IOPMAssertionID]=[]
 private var timer:Timer?
 private var deadline:TimeInterval?
 private let clock:()->TimeInterval
 var remainingSeconds:Int?
 init(clock:@escaping ()->TimeInterval = { ProcessInfo.processInfo.systemUptime }) { self.clock=clock }
 var countdownLabel:String {
  guard let remainingSeconds else { return "∞" }
  if remainingSeconds>=3600 { return String(format:"%d:%02d:%02d",remainingSeconds/3600,(remainingSeconds/60)%60,remainingSeconds%60) }
  return String(format:"%d:%02d",remainingSeconds/60,remainingSeconds%60)
 }
 var active=false
 var enabled=false
 var status="Sleep allowed"
 var durationStep:Double = {
  let preferences=UserDefaults.standard
  let old=preferences.object(forKey:"awakeDurationStep") as? Double ?? 25
  if !preferences.bool(forKey:"awakeMinuteScaleV1") {
   let minutes=old>=25 ? 121 : old*5
   preferences.set(minutes,forKey:"awakeDurationStep");preferences.set(true,forKey:"awakeMinuteScaleV1")
   return minutes
  }
  return min(121,max(0,old))
 }()
 var applicationID=UserDefaults.standard.string(forKey:"awakeApplicationID") ?? ""
 var applicationName=UserDefaults.standard.string(forKey:"awakeApplicationName") ?? ""
 var durationLabel:String { durationStep==0 ? L("Off") : durationStep>=121 ? L("Unlimited") : "\(Int(durationStep)) \(L("min"))" }
 func setDuration(_ step:Double) {
  durationStep=min(121,max(0,step.rounded()));UserDefaults.standard.set(durationStep,forKey:"awakeDurationStep")
  if durationStep==0 { stop() } else { start() }
 }
 func setTimedDuration(_ minutes:Double) { clearApplication();setDuration(minutes) }
 func start() {
  releaseAssertions();timer?.invalidate()
  if durationStep==0 { durationStep=121;UserDefaults.standard.set(durationStep,forKey:"awakeDurationStep") }
  enabled=true;UserDefaults.standard.set(true,forKey:"keepAwakeEnabled")
  deadline=durationStep>=121 ? nil : clock()+durationStep*60
  timer=Timer(timeInterval:1,repeats:true) { [weak self] _ in Task { @MainActor in self?.checkConditions() } }
  if let timer { RunLoop.main.add(timer,forMode:.common) }
  checkConditions()
  if enabled {
   closedLid.setEnabled(true,awake:true) { [weak self] ready in
    if !ready { self?.stop() }
   }
  }
 }
 private func releaseAssertions() { for id in assertions { IOPMAssertionRelease(id) };assertions=[];active=false }
 func stop(preservePreference:Bool=false) {
  closedLid.request(false)
  timer?.invalidate();timer=nil;releaseAssertions();deadline=nil;remainingSeconds=nil;enabled=false;status="Sleep allowed"
  if !preservePreference { UserDefaults.standard.set(false,forKey:"keepAwakeEnabled");durationStep=0;UserDefaults.standard.set(0,forKey:"awakeDurationStep") }
 }
 struct RunningApplication:Identifiable {
  let id:String
  let name:String
  let icon:NSImage?
 }
 var runningApplications:[RunningApplication]=[]
 func refreshRunningApplications() {
  var seen=Set<String>()
  runningApplications=NSWorkspace.shared.runningApplications.compactMap { app in
   guard app.activationPolicy == .regular,let id=app.bundleIdentifier,id != Bundle.main.bundleIdentifier,seen.insert(id).inserted else { return nil }
   return RunningApplication(id:id,name:app.localizedName ?? id,icon:app.icon)
  }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
 }
 func selectApplication(_ application:RunningApplication) {
  let timed=enabled && deadline != nil
  applicationID=application.id;applicationName=application.name;saveApplication()
  if !timed { setDuration(121) }
 }
 func clearApplication() { applicationID="";applicationName="";saveApplication() }
 private func saveApplication() { UserDefaults.standard.set(applicationID,forKey:"awakeApplicationID");UserDefaults.standard.set(applicationName,forKey:"awakeApplicationName");checkConditions() }
 static func shouldAssert(enabled:Bool,deadline:TimeInterval?,now:TimeInterval,applicationID:String,runningIDs:Set<String>) -> Bool {
  enabled && (deadline == nil || now < deadline!) && (deadline != nil || applicationID.isEmpty || runningIDs.contains(applicationID))
 }
 func checkConditions() {
  guard enabled else { return }
  remainingSeconds=deadline.map { max(0,Int(ceil($0-clock()))) }
  if let deadline,clock()>=deadline { stop();status="Timer finished";return }
  if [.critical,.serious].contains(ProcessInfo.processInfo.thermalState) { stop();status="Stopped because of high temperature";return }
  if let info=IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),let list=IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
   for source in list {
    guard let description=IOPSGetPowerSourceDescription(info,source)?.takeUnretainedValue() as? [String:Any] else { continue }
    let battery=(description[kIOPSPowerSourceStateKey] as? String)==kIOPSBatteryPowerValue
    if battery && (description[kIOPSCurrentCapacityKey] as? Int ?? 100)<=10 { stop();status="Stopped because of battery conditions";return }
   }
  }
  let running=Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
  guard Self.shouldAssert(enabled:enabled,deadline:deadline,now:clock(),applicationID:applicationID,runningIDs:running) else { stop();status="Selected application closed";return }
  if assertions.isEmpty {
   for kind in [kIOPMAssertionTypePreventUserIdleSystemSleep,kIOPMAssertionTypePreventUserIdleDisplaySleep] {
    var id:IOPMAssertionID=0
    guard IOPMAssertionCreateWithName(kind as CFString,IOPMAssertionLevel(kIOPMAssertionLevelOn),"fnota Keep Awake" as CFString,&id)==kIOReturnSuccess else { stop();status="macOS could not prevent sleep";return }
    assertions.append(id)
   }
  }
  active=true;status="Mac and display stay awake"
  closedLid.request(true,remaining:deadline.map { max(0,$0-clock()) })
 }
}
