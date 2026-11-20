import AppKit
import CryptoKit
@MainActor @Observable final class ModelStore {
 let root:URL
 var selectedID:String { didSet { preferences.set(selectedID,forKey:"speechModelID") } }
 private let preferences:UserDefaults
 var revision=0
 var status=""
 var downloading=false
 var progress=0.0
 var task:Task<Void,Never>?
 init(root:URL? = nil,preferences:UserDefaults = .standard) {
  self.preferences=preferences
  self.root=root ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("UniversalMac/Models",isDirectory:true)
  selectedID=preferences.string(forKey:"speechModelID") ?? SpeechModel.gigaAM.id
 }
 var selected:SpeechModel { SpeechModel.catalog.first { $0.id==selectedID } ?? .gigaAM }
 func folder(_ model:SpeechModel? = nil) -> URL { root.appendingPathComponent((model ?? selected).id,isDirectory:true) }
 func installed(_ model:SpeechModel) -> Bool {
  _ = revision
  return model.files.allSatisfy { let attrs=try? FileManager.default.attributesOfItem(atPath:folder(model).appendingPathComponent($0.name).path);return (attrs?[.size] as? NSNumber)?.int64Value == $0.bytes }
 }
 var installed:Bool { installed(selected) }
 func select(_ model:SpeechModel) { guard !downloading,installed(model) else { return };selectedID=model.id;status="Selected: \(model.title)" }
 nonisolated static func hash(_ url:URL) throws -> String {
  let handle=try FileHandle(forReadingFrom:url);defer { try? handle.close() }
  var hash=SHA256()
  while let data=try handle.read(upToCount:1024*1024),!data.isEmpty { hash.update(data:data) }
  return hash.finalize().map { String(format:"%02x",$0) }.joined()
 }
 func install(_ model:SpeechModel? = nil) {
  guard !downloading else { return };let model=model ?? selected
  guard !installed(model) else { select(model);return }
  downloading=true;progress=0
  let destination=folder(model)
  task=Task {
   let stage=root.appendingPathComponent(".download-"+UUID().uuidString,isDirectory:true)
   defer { try? FileManager.default.removeItem(at:stage);downloading=false;revision += 1 }
   do {
    try FileManager.default.createDirectory(at:stage,withIntermediateDirectories:true)
    for (index,file) in model.files.enumerated() {
     try Task.checkCancellation();status="Downloading \(model.title): \(file.name)…"
     let (tmp,response)=try await URLSession.shared.download(from:URL(string:file.remote)!)
     defer { try? FileManager.default.removeItem(at:tmp) }
     guard (response as? HTTPURLResponse)?.statusCode==200 else { throw AppFailure.message("Model download failed") }
     status="Checking SHA-256…"
     let digest=try await Task.detached { try Self.hash(tmp) }.value
     guard digest==file.sha256 else { throw AppFailure.message("SHA-256 mismatch: \(file.name)") }
     try Task.checkCancellation()
     try FileManager.default.moveItem(at:tmp,to:stage.appendingPathComponent(file.name))
     progress=Double(index+1)/Double(model.files.count)
    }
    if FileManager.default.fileExists(atPath:destination.path) { try FileManager.default.removeItem(at:destination) }
    try FileManager.default.moveItem(at:stage,to:destination)
    selectedID=model.id;status="Model installed, verified and selected"
   } catch is CancellationError { status="Cancel" }
   catch { status=error.localizedDescription }
  }
 }
 func verify() {
  guard !downloading else { return };let model=selected;let url=folder(model);downloading=true;status="Checking SHA-256…"
  task=Task {
   defer { downloading=false }
   do {
    for file in model.files {
     let path=url.appendingPathComponent(file.name)
     let digest=try await Task.detached { try Self.hash(path) }.value
     guard digest==file.sha256 else { throw AppFailure.message("Damaged file: \(file.name)") }
    };status="All SHA-256 checksums match"
   } catch { status=error.localizedDescription }
  }
 }
 func delete(_ model:SpeechModel) throws {
  guard !downloading else { throw AppFailure.message("Wait for the download to finish") }
  try FileManager.default.removeItem(at:folder(model));revision += 1
  status="Model deleted. You can download it again."
 }
 func remove(_ model:SpeechModel? = nil) {
  guard !downloading else { return };let model=model ?? selected
  let alert=NSAlert();alert.messageText="Delete \(model.title)?";alert.informativeText="This frees \(model.size). You can download the model again.";alert.addButton(withTitle:L("Delete"));alert.addButton(withTitle:L("Cancel"))
  guard alert.runModal() == .alertFirstButtonReturn else { return }
  do { try delete(model) } catch { status=error.localizedDescription }
 }
}
