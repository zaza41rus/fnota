import Foundation
@main struct SpeechCatalogIntegrationSmoke {
 @MainActor static func main() async throws {
  let root=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
  let prefs=UserDefaults(suiteName:"UMSpeechCatalogIntegration")!
  defer { prefs.removePersistentDomain(forName:"UMSpeechCatalogIntegration") }
  let store=ModelStore(root:root,preferences:prefs)
  precondition(SpeechModel.catalog.count==11)
  let engine=GigaAMEngine()
  precondition(SpeechModel.catalog.filter { $0.dictationMode == .live }.map(\.id) == [SpeechModel.tOne.id])
  for model in SpeechModel.catalog where model.dictationMode == .afterRecording {
   precondition(store.installed(model),model.id)
   store.select(model);precondition(store.selectedID==model.id)
   let audio=model.architecture == .senseVoice ? "/tmp/um-english.wav" : "/tmp/universalmac-speech-test.wav"
   let text=try await engine.transcribe(file:URL(fileURLWithPath:audio),modelFolder:store.folder())
   let needle=model.architecture == .senseVoice ? "internet" : "интернет"
   precondition(text.lowercased().contains(needle),"\(model.id): \(text)")
   print("PASS select + Swift adapter \(model.id): \(text)")
  }
  // A second selection verifies state and recognizer configuration do not leak.
  store.select(.gigaAM)
  let text=try await engine.transcribe(file:URL(fileURLWithPath:"/tmp/universalmac-speech-test.wav"),modelFolder:store.folder())
  precondition(text.contains("распознавание"))
  print("PASS switch back to GigaAM")
 }
}
