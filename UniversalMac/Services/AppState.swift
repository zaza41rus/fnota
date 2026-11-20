import AppKit
import ServiceManagement
import ApplicationServices
@MainActor @Observable final class AppState {
 let models:ModelStore
 var sleep = SleepController()
 let bridge = SelectionBridge()
 let overlay = Overlay()
 let audio = AudioCapture()
 let speech = GigaAMEngine()
 let translator = LocalTranslationEngine()
 let secondTranslator=LocalTranslationEngine()
 var uiLanguage=UserDefaults.standard.string(forKey:"uiLanguage") ?? "en" { didSet { UserDefaults.standard.set(uiLanguage,forKey:"uiLanguage") } }
 var voiceEnabled:Bool { models.installed }
 var translationEnabled:Bool { !translationFolders.isEmpty && translationFolders.allSatisfy { (try? TranslationModels.inspect($0)) != nil } }
 var settingsPage="speech"
 private var lastAvailability:(Bool,Bool)?
 var extraTranslationFolders:[URL]=[]
 var translationFolders:[URL] { if let translationFolder { return [translationFolder]+extraTranslationFolders };return [] }
 var translationModels = TranslationModels()
 let browserTranslation = BrowserTranslation()
 let permissions=PermissionDiagnostics()
 var translationTask:Task<Void,Never>?
 private var lastSelection:(original:String,translated:String)?
 let shortcuts = GlobalShortcuts()
 let keyboardLayoutSwitcher = KeyboardLayoutSwitcher()
 var autoSwitchKeyboardLayout = UserDefaults.standard.bool(forKey:"autoSwitchKeyboardLayout") {
  didSet {
   UserDefaults.standard.set(autoSwitchKeyboardLayout,forKey:"autoSwitchKeyboardLayout")
   refreshKeyboardLayoutSwitcher()
  }
 }
 private(set) var keyboardLayoutNames:[String]=[]
 private(set) var keyboardLayoutSwitcherRunning = false
 private(set) var keyboardLayoutSwitcherPausedForRuSwitcher = false
 func refreshKeyboardLayoutSwitcher() {
  keyboardLayoutNames = LayoutSwitcher.automaticPair(from:LayoutSwitcher.installedLayouts()).map(LayoutSwitcher.sourceName)
  keyboardLayoutSwitcherPausedForRuSwitcher = autoSwitchKeyboardLayout && keyboardLayoutSwitcher.isRuSwitcherRunning
  if autoSwitchKeyboardLayout && !keyboardLayoutSwitcherPausedForRuSwitcher && AXIsProcessTrusted() { keyboardLayoutSwitcher.start() }
  else { keyboardLayoutSwitcher.stop() }
  keyboardLayoutSwitcherRunning = keyboardLayoutSwitcher.isRunning
 }
 let voiceBinding = ShortcutBinding.voice
 let translationBinding = ShortcutBinding.translate
 let holdToTalk=true
 var startingRecording = false
 private var voiceHeld = false
 private var heldSession = false
 private var translating = false
 var recording = false
 var processing = false
 var result = ""
 var message = "Ready"
 var shortcutErrors:[String] = []
 var loginEnabled = false
 var loginNeedsApproval = false
 private var lastAXTrusted = AXIsProcessTrusted()
 private var systemObserver:NSObjectProtocol?
 private var layoutAppObservers:[NSObjectProtocol]=[]
 var translationFolder:URL? { didSet { UserDefaults.standard.set(translationFolder,forKey:"translationFolder") } }
 init(models:ModelStore=ModelStore()) {
  self.models=models
  let saved=UserDefaults.standard.url(forKey:"translationFolder")
  if let saved,(try? TranslationModels.inspect(saved)) != nil { translationFolder=saved }
  else { translationFolder=nil }
  let extraPaths=UserDefaults.standard.stringArray(forKey:"translationExtraFolders") ?? []
  extraTranslationFolders=extraPaths.map { URL(fileURLWithPath:$0) }.filter { (try? TranslationModels.inspect($0)) != nil }
  if extraTranslationFolders.count != extraPaths.count { translationFolder=nil;extraTranslationFolders=[] }

 }
 private var servicesStarted = false
 func startServices() {
  guard !servicesStarted else { return };servicesStarted = true
  if UserDefaults.standard.bool(forKey:"keepAwakeEnabled") { sleep.start() }
  overlay.onStatus = { [weak self] text in self?.message = text }
  shortcuts.onAction = { [weak self] id,down in
   guard let self else { return }
   if id == 1,self.voiceEnabled {
    if self.voiceBinding.isFn || self.holdToTalk {
     self.voiceHeld = down
     if down { self.heldSession = true; Task { await self.beginRecording() } }
     else if self.recording,self.heldSession { Task { await self.toggleRecording() } }
    } else if down { self.heldSession = false; Task { await self.toggleRecording() } }
   }
   if id == 2,down,self.translationEnabled { self.translateContext() }
  }
  reconnectShortcuts()
  refreshSystemState()
  layoutAppObservers = [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification].map { notification in
   NSWorkspace.shared.notificationCenter.addObserver(forName:notification,object:nil,queue:.main) { [weak self] event in
    guard (event.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == "com.ruswitcher.app" else { return }
    Task { @MainActor in self?.refreshKeyboardLayoutSwitcher() }
   }
  }
  systemObserver = NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] _ in
   Task { @MainActor in
    self?.keyboardLayoutSwitcher.reset()
    self?.refreshSystemState()
   }
  }
 }
 func refreshSystemState() {
  refreshKeyboardLayoutSwitcher()
  permissions.refresh(voice:voiceEnabled,translation:translationEnabled)
  let status=SMAppService.mainApp.status
  loginEnabled = status == .enabled || status == .requiresApproval
  loginNeedsApproval = status == .requiresApproval
  let trusted=AXIsProcessTrusted()
  if !recording,!startingRecording,!processing,(trusted != lastAXTrusted || (trusted && !shortcutErrors.isEmpty) || lastAvailability?.0 != voiceEnabled || lastAvailability?.1 != translationEnabled) {
   lastAXTrusted=trusted;reconnectShortcuts()
  }
 }
 func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
 func reconnectShortcuts() {
  lastAvailability=(voiceEnabled,translationEnabled)
  shortcutErrors=shortcuts.register(voice:voiceBinding,translation:translationBinding,voiceEnabled:voiceEnabled,translationEnabled:translationEnabled)
 }
 func beginRecording() async {
  guard voiceEnabled else { return }
  if translating { translationTask?.cancel(); await translationTask?.value }
  if heldSession && !voiceHeld { return }
  guard !recording,!startingRecording,!processing else { return }
  guard models.installed else { message = "Install a dictation model in Settings → Models"; overlay.show(message); return }
  startingRecording = true
  await bridge.prepareDictationTarget()
  do {
   try await audio.start(); recording = true; startingRecording = false
   message = heldSession ? "Recording · release \(voiceBinding.label) to insert text" : "Recording · press \(voiceBinding.label) to stop"
   overlay.show(message,persistent:true)
   if heldSession && !voiceHeld { await toggleRecording() }
  } catch { startingRecording = false; message = error.localizedDescription; overlay.show(message) }
 }
 func toggleRecording() async {
  guard !processing else { return }
  if recording {
   recording = false; processing = true; message = "Recognizing locally…"; overlay.show(message,persistent:true)
   do {
    let file = try audio.stop(); defer { try? FileManager.default.removeItem(at:file) }
    let text = try await speech.transcribe(file:file,modelFolder:models.folder())
    if !text.isEmpty { result += (result.isEmpty || result.last?.isWhitespace == true ? "" : " ") + text }
    if text.isEmpty { message = "No speech detected" }
    else {
     let insertion = bridge.dictationText(text)
     NSPasteboard.general.clearContents();NSPasteboard.general.setString(insertion,forType:.string)
     if bridge.insert(insertion,pasteFallback:true) { message = "Text inserted and copied" }
     else { message = "Text copied: \(bridge.failureReason). Paste with ⌘V" }
    }
    overlay.show(message)
   } catch { message = error.localizedDescription; overlay.show(message) }
   processing = false
  } else { heldSession = false; await beginRecording() }
 }

 func login(_ enabled:Bool) {
  do {
   if enabled { if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() } }
   else { try SMAppService.mainApp.unregister() }
   refreshSystemState()
   message = loginNeedsApproval ? "Approve login launch in macOS Settings" : "Login launch updated"
  } catch { refreshSystemState();message = error.localizedDescription }
 }

 func activateTranslationModel(_ folder:URL) async { await activateTranslationRoute([folder]) }
 func activateTranslationRoute(_ folders:[URL]) async {
  guard !folders.isEmpty,folders.count<=2 else { return }
  let previous=translationTask;previous?.cancel();await previous?.value
  await translator.unload();await secondTranslator.unload()
  translationFolder=folders[0];extraTranslationFolders=Array(folders.dropFirst())
  UserDefaults.standard.set(extraTranslationFolders.map(\.path),forKey:"translationExtraFolders")
  message="Translation model selected"
 }
 private func translate(_ text:String,folders:[URL]) async throws -> String {
  guard let first=folders.first else { throw AppFailure.message("Install a translation model in Settings → Models") }
  var output=try await translator.translate(text,folder:first)
  if folders.count>1 { output=try await secondTranslator.translate(output,folder:folders[1]) }
  return output
 }
 func removeTranslationModel(_ folder:URL) {
  guard !recording,!startingRecording,!processing,!translationModels.busy else { return }
  let alert=NSAlert();alert.messageText=L("Delete translation model?");alert.informativeText=L("Model files will be deleted. You can download them again.");alert.addButton(withTitle:L("Delete"));alert.addButton(withTitle:L("Cancel"))
  guard alert.runModal() == .alertFirstButtonReturn else { return }
  translationModels.busy=true
  Task {
   defer { translationModels.busy=false }
   translationTask?.cancel();await translationTask?.value;await translator.unload();await secondTranslator.unload()
   do {
    try translationModels.delete(folder)
    if translationFolders.contains(folder) { translationFolder=nil;extraTranslationFolders=[];UserDefaults.standard.removeObject(forKey:"translationExtraFolders") }
    message="Translation model deleted"
   } catch { translationModels.status=error.localizedDescription }
  }
 }
 func translateContext() {
  guard translationEnabled else { return }
  guard !recording,!startingRecording,!processing else { message = "Wait for dictation to finish"; return }
  if translating { translationTask?.cancel(); overlay.show("Stopping translation and restoring original…"); return }
  bridge.captureTarget()
  let text = bridge.selectedText() ?? ""
  // Browser DOM handles selection boundaries, inline formatting, and original restoration.
  if browserTranslation.isBrowser && (!bridge.canInsert || text.isEmpty) { translatePage(); return }
  guard !text.isEmpty else { overlay.show("Select text in this application. Full-page translation is available in Safari and Chrome."); return }
  if let lastSelection,text == lastSelection.translated {
   if bridge.insert(lastSelection.original,selectInserted:true) { self.lastSelection = nil; overlay.show("Original selection restored"); return }
  }
  if let lastSelection,text == lastSelection.original,!bridge.canInsert { overlay.hide(); self.lastSelection = nil; return }
  let folders=translationFolders
  guard !folders.isEmpty else { overlay.show("Install a translation model in Settings → Models"); return }
  translating = true
  translationTask = Task {
   defer { translating = false }
   do {
    let translated = try await translate(text,folders:folders); try Task.checkCancellation()
    if bridge.selectedText() == text { _ = bridge.insert(translated,selectInserted:true) }
    lastSelection = (text,translated); overlay.show(translated)
   } catch is CancellationError { overlay.show("Translation cancelled") }
   catch { overlay.show(error.localizedDescription) }
  }
 }
 func translatePage(browserName:String? = nil) {
  guard translationEnabled else { return }
  guard !recording,!startingRecording,!processing else { message = "Wait for dictation to finish"; return }
  if translating { translationTask?.cancel(); return }
  do {
   let request = try browserTranslation.begin(browserName:browserName)
   if request.restored { overlay.show(request.selection ? "Original selection restored" : "Original page restored"); return }
   guard !request.items.isEmpty else { overlay.show("No text available for translation"); return }
   let folders=translationFolders
  guard !folders.isEmpty else { overlay.show("Install a translation model in Settings → Models"); return }
   translating = true
   translationTask = Task {
    defer { translating = false }
    do {
     for (i,item) in request.items.enumerated() {
      try Task.checkCancellation()
      let text = try await translate(item.text,folders:folders)
      try Task.checkCancellation(); try browserTranslation.apply(id:item.id,text:text)
      message = "Translating: \(i+1) / \(request.items.count)"
     }
     browserTranslation.finish(); overlay.show(request.selection ? "Selection translated" : "Page translated")
    } catch {
     browserTranslation.rollback()
     message = error is CancellationError ? "Translation cancelled, original restored" : error.localizedDescription
     overlay.show(message)
    }
   }
  } catch { message = error.localizedDescription; overlay.show(message) }
 }
}
