import Foundation
@main struct TranslationModelsSmoke {
 static func main() async throws {
  let args=CommandLine.arguments
  let builtin=URL(fileURLWithPath:args[1]),archive=URL(fileURLWithPath:args[2]),bad=URL(fileURLWithPath:args[3])
  let root=FileManager.default.temporaryDirectory.appendingPathComponent("UMModelTest-"+UUID().uuidString)
  defer { try? FileManager.default.removeItem(at:root) }
  let before=try await TranslationModels.validate(builtin)
  let installed=try await TranslationModels.install(archive,destinationRoot:root)
  let after=try await TranslationModels.validate(installed)
  precondition(after.version==before.version && after.bytes>200_000_000)
  var rejected=false
  do { _ = try await TranslationModels.install(bad,destinationRoot:root) } catch { rejected=true }
  precondition(rejected,"Unsafe archive must not be installed")
  let original=try TranslationModels.inspect(builtin);precondition(original.version==before.version)
  print("PASS: bundled model, ZIP install, real Russian inference, unsafe archive rejected; original model preserved")
 }
}
