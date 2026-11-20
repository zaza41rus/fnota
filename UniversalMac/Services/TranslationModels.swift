import AppKit
import CryptoKit
struct TranslationModelInfo:Sendable {
 let folder:URL
 let version:String
 let from:String
 let to:String
 let bytes:Int64
 var label:String { "Argos \(from) → \(to) · \(version)" }
 var size:String { ByteCountFormatter.string(fromByteCount:bytes,countStyle:.file) }
}
struct TranslationCatalogItem:Decodable,Identifiable,Sendable {
 let package_version:String
 let from_code:String
 let to_code:String
 let links:[String]
 var label:String { "\(Self.language(from_code)) → \(Self.language(to_code))" }
 static func language(_ code:String) -> String { Locale(identifier:UserDefaults.standard.string(forKey:"uiLanguage") ?? "en").localizedString(forIdentifier:code=="zt" ? "zh_Hant" : code=="pb" ? "pt_BR" : code) ?? code }
 var id:String { "\(from_code)-\(to_code)-\(package_version)" }
}
@MainActor @Observable final class TranslationModels {
 nonisolated static var managedRoot:URL { FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("UniversalMac/Models/Translation",isDirectory:true) }
 var installedModels:[TranslationModelInfo]=[]
 init() { refreshInstalled() }
 func refreshInstalled() {
  let folders=(try? FileManager.default.contentsOfDirectory(at:Self.managedRoot,includingPropertiesForKeys:nil)) ?? []
  installedModels=folders.compactMap { try? Self.inspect($0) }.sorted { $0.folder.path < $1.folder.path }
 }
 func delete(_ folder:URL) throws {
  guard folder.deletingLastPathComponent().standardizedFileURL==Self.managedRoot.standardizedFileURL else { throw AppFailure.message("Only models in the managed folder can be deleted") }
  try FileManager.default.removeItem(at:folder);refreshInstalled();status="Translation model deleted"
 }
 var available:[TranslationCatalogItem] = []
 var allAvailable:[TranslationCatalogItem]=[]
 var sourceLanguage="en"
 var targetLanguage="ru"
 var languages:[String] { Array(Set(allAvailable.flatMap { [$0.from_code,$0.to_code] })).sorted() }
 var plan:[TranslationCatalogItem] {
  guard sourceLanguage != targetLanguage else { return [] }
  if let direct=allAvailable.first(where:{$0.from_code==sourceLanguage && $0.to_code==targetLanguage}) { return [direct] }
  if let first=allAvailable.first(where:{$0.from_code==sourceLanguage && $0.to_code=="en"}),let second=allAvailable.first(where:{$0.from_code=="en" && $0.to_code==targetLanguage}) { return [first,second] }
  return []
 }
 func installed(_ item:TranslationCatalogItem) -> TranslationModelInfo? { installedModels.first { $0.from==item.from_code && $0.to==item.to_code && $0.version==item.package_version } }
 func downloadPlan(activate:@escaping ([URL]) async -> Void) {
  guard !busy,!plan.isEmpty else { return };let items=plan;busy=true
  task=Task {
   defer { busy=false;refreshInstalled() }
   do {
    var folders:[URL]=[]
    for item in items {
     if let ready=installed(item) { folders.append(ready.folder);continue }
     status="Downloading \(item.label)…"
     let destination=try await Self.fetch(item)
     folders.append(destination);refreshInstalled()
    }
    await activate(folders);status="Translation route is ready"
   } catch { status=error.localizedDescription }
  }
 }
 nonisolated private static func fetch(_ item:TranslationCatalogItem) async throws -> URL {
  guard let link=item.links.compactMap(URL.init(string:)).first(where:{$0.scheme=="https" && $0.host=="argos-net.com"}) else { throw AppFailure.message("No supported download URL") }
  let (file,response)=try await URLSession.shared.download(from:link)
  defer { try? FileManager.default.removeItem(at:file) }
  guard (response as? HTTPURLResponse)?.statusCode==200 else { throw AppFailure.message("Model download failed") }
  try Task.checkCancellation()
  let destination=try await install(file)
  let info=try inspect(destination)
  guard info.from==item.from_code,info.to==item.to_code else { try? FileManager.default.removeItem(at:destination);throw AppFailure.message("Downloaded language pair does not match the catalog") }
  return destination
 }

 var status=""
 var busy=false
 var task:Task<Void,Never>?
 nonisolated static func inspect(_ folder:URL) throws -> TranslationModelInfo {
  let metadata=folder.appendingPathComponent("metadata.json")
  guard let data=try? Data(contentsOf:metadata),let info=try JSONSerialization.jsonObject(with:data) as? [String:Any],let from=info["from_code"] as? String,let to=info["to_code"] as? String,!from.isEmpty,!to.isEmpty,from != to else { throw AppFailure.message("A compatible Argos model with language metadata is required") }
  for file in ["model/model.bin"] {
   guard FileManager.default.fileExists(atPath:folder.appendingPathComponent(file).path) else { throw AppFailure.message("Package is missing \(file)") }
  }
  guard ["sentencepiece.model","bpe.model"].contains(where:{FileManager.default.fileExists(atPath:folder.appendingPathComponent($0).path)}) else { throw AppFailure.message("Missing SentencePiece or BPE tokenizer") }
  var bytes:Int64=0
  if let files=FileManager.default.enumerator(at:folder,includingPropertiesForKeys:[.fileSizeKey,.isRegularFileKey]) {
   for case let url as URL in files { let values=try url.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey]);if values.isRegularFile==true { bytes += Int64(values.fileSize ?? 0) } }
  }
  return TranslationModelInfo(folder:folder,version:info["package_version"] as? String ?? "unknown",from:from,to:to,bytes:bytes)
 }
 nonisolated static func validate(_ folder:URL) async throws -> TranslationModelInfo {
  let info=try inspect(folder)
  let engine=LocalTranslationEngine()
  do {
   let samples=["en":"The application works without the internet.","es":"La aplicación funciona sin internet.","ru":"Приложение работает без интернета.","zh":"这个应用程序不需要互联网。","ko":"이 응용 프로그램은 인터넷 없이 작동합니다."]
   let text=try await engine.translate(samples[info.from] ?? "Hello",folder:folder)
   await engine.unload()
   guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw AppFailure.message("Model returned no text during the compatibility test") }
   return info
  } catch { await engine.unload();throw error }
 }
 func refreshCatalog() {
  guard !busy else { return };busy=true;status="Loading official catalog…"
  task=Task {
   defer { busy=false;refreshInstalled() }
   do {
    let (data,response)=try await URLSession.shared.data(from:URL(string:"https://raw.githubusercontent.com/argosopentech/argospm-index/main/index.json")!)
    guard (response as? HTTPURLResponse)?.statusCode==200 else { throw AppFailure.message("Catalog unavailable") }
    let all=try JSONDecoder().decode([TranslationCatalogItem].self,from:data)
    allAvailable=all.sorted { $0.id < $1.id };available=allAvailable
    status="Available language pairs: \(all.count). Choose a direction below."
   } catch { status=error.localizedDescription }
  }
 }
 func chooseFolder(activate:@escaping (URL) async -> Void) {
  guard !busy else { return }
  let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false
  guard panel.runModal() == .OK,let folder=panel.url else { return }
  busy=true;status="Checking and copying model…"
  task=Task {
   defer { busy=false;refreshInstalled() }
   do {
    _ = try await Self.validate(folder)
    let destination=try await Task.detached { try Self.copyManaged(folder,root:Self.managedRoot) }.value
    await activate(destination);status="Model imported and selected"
   } catch { status=error.localizedDescription }
  }
 }
 func checkAndActivate(_ folder:URL,activate:@escaping (URL) async -> Void) {
  guard !busy else { return };busy=true;status="Compatibility test…"
  task=Task {
   defer { busy=false;refreshInstalled() }
   do { let info=try await Self.validate(folder);try Task.checkCancellation();await activate(folder);status="Selected \(info.label) · \(info.size)" }
   catch { status=error is CancellationError ? "Cancel" : error.localizedDescription }
  }
 }
 func importArchive(activate:@escaping (URL) async -> Void) {
  guard !busy else { return }
  let panel=NSOpenPanel();panel.message="Choose a compatible .argosmodel or ZIP package";panel.canChooseDirectories=false
  guard panel.runModal() == .OK,let file=panel.url else { return }
  installArchive(file,activate:activate)
 }
 func download(_ item:TranslationCatalogItem,activate:@escaping (URL) async -> Void) {
  guard !busy,let link=item.links.compactMap(URL.init(string:)).first(where:{$0.scheme=="https" && $0.host=="argos-net.com"}) else { return }
  busy=true;status="Downloading Argos \(item.package_version)…"
  task=Task {
   defer { busy=false;refreshInstalled() }
   do {
    let (file,response)=try await URLSession.shared.download(from:link)
    defer { try? FileManager.default.removeItem(at:file) }
    guard (response as? HTTPURLResponse)?.statusCode==200 else { throw AppFailure.message("Model download failed") }
    try Task.checkCancellation();status="Checking model package…"
    let destination=try await Self.install(file)
    await activate(destination);status="Downloaded and selected Argos \(item.package_version)"
   } catch { status=error is CancellationError ? "Cancel" : error.localizedDescription }
  }
 }
 private func installArchive(_ file:URL,activate:@escaping (URL) async -> Void) {
  busy=true;status="Checking model package…"
  task=Task {
   defer { busy=false;refreshInstalled() }
   do { let destination=try await Self.install(file);await activate(destination);status="Package installed and selected" }
   catch { status=error is CancellationError ? "Cancel" : error.localizedDescription }
  }
 }
 nonisolated private static func run(_ path:String,_ arguments:[String]) throws -> String {
  let process=Process();let output=Pipe();process.executableURL=URL(fileURLWithPath:path);process.arguments=arguments;process.standardOutput=output;process.standardError=FileHandle.nullDevice
  try process.run();let data=output.fileHandleForReading.readDataToEndOfFile();process.waitUntilExit()
  guard process.terminationStatus==0 else { throw AppFailure.message("Could not read the model archive") }
  return String(decoding:data,as:UTF8.self)
 }
 nonisolated static func install(_ archive:URL,destinationRoot:URL? = nil) async throws -> URL {
  try await Task.detached {
   let fm=FileManager.default
   let temporary=fm.temporaryDirectory.appendingPathComponent("UMTranslation-"+UUID().uuidString,isDirectory:true)
   try fm.createDirectory(at:temporary,withIntermediateDirectories:true)
   defer { try? fm.removeItem(at:temporary) }
   let names=try run("/usr/bin/zipinfo",["-1",archive.path])
   guard !names.split(separator:"\n").contains(where:{ $0.hasPrefix("/") || $0.split(separator:"/").contains("..") || $0.contains("\\") }) else { throw AppFailure.message("Unsafe paths in archive") }
   let listing=try run("/usr/bin/zipinfo",["-l",archive.path])
   guard !listing.split(separator:"\n").contains(where:{$0.hasPrefix("l")}) else { throw AppFailure.message("Symbolic links in model archives are not allowed") }
   try Task.checkCancellation()
   _ = try run("/usr/bin/ditto",["-x","-k",archive.path,temporary.path])
   var folders:[URL]=[]
   if fm.fileExists(atPath:temporary.appendingPathComponent("metadata.json").path) { folders.append(temporary) }
   if let files=fm.enumerator(at:temporary,includingPropertiesForKeys:[.isSymbolicLinkKey]) {
    for file in (files.allObjects as? [URL] ?? []) {
     guard try file.resourceValues(forKeys:[.isSymbolicLinkKey]).isSymbolicLink != true else { throw AppFailure.message("Symbolic links in model packages are not allowed") }
     if file.lastPathComponent=="metadata.json" { folders.append(file.deletingLastPathComponent()) }
    }
   }
   let compatible=folders.filter { (try? inspect($0)) != nil }
   guard let source=compatible.first,Set(compatible).count==1 else { throw AppFailure.message("The archive must contain one compatible Argos model") }
   _ = try await validate(source)
   try Task.checkCancellation()
   return try copyManaged(source,root:destinationRoot ?? managedRoot)
  }.value
 }
 nonisolated static func copyManaged(_ source:URL,root:URL) throws -> URL {
  let fm=FileManager.default
  try fm.createDirectory(at:root,withIntermediateDirectories:true)
  let destination=root.appendingPathComponent(UUID().uuidString,isDirectory:true)
  try fm.createDirectory(at:destination,withIntermediateDirectories:true)
  do {
   try fm.copyItem(at:source.appendingPathComponent("model"),to:destination.appendingPathComponent("model"))
   for relative in ["metadata.json","sentencepiece.model","bpe.model","README.md"] {
    let file=source.appendingPathComponent(relative)
    if fm.fileExists(atPath:file.path) { try fm.copyItem(at:file,to:destination.appendingPathComponent(relative)) }
   }
   return destination
  } catch { try? fm.removeItem(at:destination);throw error }
 }

}
