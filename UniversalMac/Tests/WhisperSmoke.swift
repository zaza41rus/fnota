import Foundation
@main struct WhisperSmoke {
 @MainActor static func main() async throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent("UMWhisperTest-"+UUID().uuidString)
  let preferences=UserDefaults(suiteName:"UMWhisperTest")!
  defer { try? FileManager.default.removeItem(at:root);preferences.removePersistentDomain(forName:"UMWhisperTest") }
  let models=ModelStore(root:root,preferences:preferences)
  models.install(.whisperTiny);await models.task?.value
  guard models.installed(.whisperTiny) else { throw AppFailure.message(models.status) }
  let engine=GigaAMEngine()
  for path in CommandLine.arguments.dropFirst() {
   let text=try await engine.transcribe(file:URL(fileURLWithPath:path),modelFolder:models.folder())
   guard !text.isEmpty else { throw AppFailure.message("Whisper returned empty text") }
   print("PASS Whisper native: \(text)")
  }
  try models.delete(.whisperTiny);precondition(!models.installed)
 }
}
