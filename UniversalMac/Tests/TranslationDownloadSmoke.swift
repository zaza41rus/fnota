import Foundation
@main struct TranslationDownloadSmoke {
 @MainActor static func main() async throws {
  let models=TranslationModels()
  models.refreshCatalog();await models.task?.value
  guard let item=models.available.first else { throw AppFailure.message(models.status) }
  var installed:URL?
  models.download(item) { installed=$0 }
  await models.task?.value
  guard let folder=installed else { throw AppFailure.message(models.status) }
  defer { try? FileManager.default.removeItem(at:folder) }
  let info=try await TranslationModels.validate(folder)
  print("PASS: official catalog → HTTPS download → safe extraction → native Russian translation; version \(info.version), bytes \(info.bytes)")
 }
}
