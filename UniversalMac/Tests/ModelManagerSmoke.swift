import Foundation
@main struct ModelManagerSmoke {
 @MainActor static func main() async throws {
  let fm=FileManager.default
  let root=fm.temporaryDirectory.appendingPathComponent("UMManagerTest-"+UUID().uuidString)
  let suite="UMManagerTest-"+UUID().uuidString
  let preferences=UserDefaults(suiteName:suite)!
  defer { try? fm.removeItem(at:root);preferences.removePersistentDomain(forName:suite) }
  let models=ModelStore(root:root,preferences:preferences)
  precondition(!models.installed)
  models.install(.ctc);await models.task?.value
  guard models.installed(.ctc),models.selectedID==SpeechModel.ctc.id else { throw AppFailure.message(models.status) }
  models.verify();await models.task?.value
  precondition(models.status=="Все SHA-256 совпали")
  let text=try await GigaAMEngine().transcribe(file:URL(fileURLWithPath:CommandLine.arguments[1]),modelFolder:models.folder())
  guard text.lowercased().contains("без интернета") else { throw AppFailure.message("Unexpected recognition: \(text)") }
  let reloaded=ModelStore(root:root,preferences:preferences)
  precondition(reloaded.selectedID==SpeechModel.ctc.id && reloaded.installed)
  try models.delete(.ctc)
  precondition(!models.installed && !fm.fileExists(atPath:models.folder().path))
  print("PASS: fresh install → HTTPS+SHA256 → alternative native speech → saved selection → delete frees model files")
 }
}
