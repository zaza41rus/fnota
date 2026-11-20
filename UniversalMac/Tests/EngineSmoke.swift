import Foundation
@main struct EngineSmoke {
 static func main() async throws {
  let args=CommandLine.arguments
  guard args.count==4 else { fatalError("audio modelFolder translationFolder") }
  let start=Date()
  let text=try await GigaAMEngine().transcribe(file:URL(fileURLWithPath:args[1]),modelFolder:URL(fileURLWithPath:args[2]))
  guard text.contains("распознавание"),text.contains("без интернета") else { fatalError("Speech mismatch: \(text)") }
  print("GigaAM Swift adapter: PASS (\(Date().timeIntervalSince(start)) s): \(text)")
  let engine=LocalTranslationEngine()
  let translated=try await engine.translate("The application works without the internet.",folder:URL(fileURLWithPath:args[3]))
  guard translated.contains("интернет") else { fatalError("Translation mismatch") }
  print("Translation Swift adapter: PASS: \(translated)")
  await engine.unload()
 }
}
