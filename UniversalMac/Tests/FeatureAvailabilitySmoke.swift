import Foundation
@main struct FeatureAvailabilitySmoke {
 @MainActor static func main() throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent("UMAvailability-"+UUID().uuidString)
  let suite="UMAvailability-"+UUID().uuidString
  let preferences=UserDefaults(suiteName:suite)!
  let oldVoice=UserDefaults.standard.data(forKey:"voiceShortcut")
  let oldTranslation=UserDefaults.standard.data(forKey:"translationShortcut")
  defer {
   try? FileManager.default.removeItem(at:root);preferences.removePersistentDomain(forName:suite)
   UserDefaults.standard.set(oldVoice,forKey:"voiceShortcut");UserDefaults.standard.set(oldTranslation,forKey:"translationShortcut")
  }
  ShortcutBinding(keyCode:40,modifiers:1,label:"old custom shortcut").save("voiceShortcut")
  ShortcutBinding(keyCode:41,modifiers:2,label:"old custom shortcut").save("translationShortcut")
  let models=ModelStore(root:root,preferences:preferences)
  let state=AppState(models:models)
  precondition(state.voiceBinding == .voice && state.translationBinding == .translate && state.holdToTalk)
  precondition(!state.voiceEnabled)
  try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
  try FileManager.default.copyItem(at:URL(fileURLWithPath:CommandLine.arguments[1]),to:models.folder(.gigaAM))
  models.revision += 1
  precondition(state.voiceEnabled)
  try models.delete(.gigaAM)
  precondition(!state.voiceEnabled)
  print("PASS fixed Fn gestures ignore legacy custom shortcuts; install enables dictation; delete disables it")
 }
}
