import Foundation
@main struct MultilingualModelsSmoke {
 @MainActor static func main() async throws {
  setbuf(stdout,nil)
  let models=TranslationModels();models.refreshCatalog();await models.task?.value
  guard models.allAvailable.count>=90 else { throw AppFailure.message(models.status) }
  for (source,target,input,pattern) in [("es","en","La aplicación funciona sin internet.","internet"),("zh","ko","这个应用程序不需要互联网。","[가-힣]")] {
   models.sourceLanguage=source;models.targetLanguage=target
   let before=Set(models.installedModels.map(\.folder));var route:[URL]=[]
   models.downloadPlan { route=$0 };await models.task?.value
   guard route.count==(source=="zh" ? 2 : 1) else { throw AppFailure.message(models.status) }
   var output=input
   for folder in route { let engine=LocalTranslationEngine();output=try await engine.translate(output,folder:folder);await engine.unload() }
   guard output.range(of:pattern,options:.regularExpression) != nil else { throw AppFailure.message("Unexpected output: \(output)") }
   print("PASS \(source) → \(target), \(route.count) model(s): \(output)")
   for folder in route where !before.contains(folder) { try models.delete(folder) }
  }
  let original=try TranslationModels.inspect(URL(fileURLWithPath:CommandLine.arguments[1]))
  precondition(original.from=="en" && original.to=="ru")
  print("PASS original user model retained")
 }
}
