import Foundation
import CryptoKit
// Run before replacing an older app which bundled model weights.
let fm=FileManager.default
let preferences=UserDefaults(suiteName:"local.safarilocalru.UniversalMac")!
let resources=URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent("Contents/Resources/Models")
let root=fm.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("UniversalMac/Models")
func digest(_ url:URL) throws -> String {
 let file=try FileHandle(forReadingFrom:url);defer { try? file.close() };var hash=SHA256()
 while let data=try file.read(upToCount:1048576),!data.isEmpty { hash.update(data:data) }
 return hash.finalize().map { String(format:"%02x",$0) }.joined()
}
func copyChecked(_ source:URL,_ destination:URL) throws {
 let files=(fm.enumerator(at:source,includingPropertiesForKeys:[.isRegularFileKey])?.allObjects as? [URL] ?? []).filter { (try? $0.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile)==true }
 guard !files.isEmpty else { throw NSError(domain:"migration",code:1,userInfo:[NSLocalizedDescriptionKey:"Source model is empty"]) }
 try fm.createDirectory(at:destination,withIntermediateDirectories:true)
 for file in files {
  let relative=String(file.path.dropFirst(source.path.count+1));let target=destination.appendingPathComponent(relative)
  if !fm.fileExists(atPath:target.path) { try fm.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true);try fm.copyItem(at:file,to:target) }
  guard try digest(file)==digest(target) else { throw NSError(domain:"migration",code:2,userInfo:[NSLocalizedDescriptionKey:"Model migration checksum mismatch"]) }
 }
}
let speechID="gigaam-v3-e2e-ctc-int8"
let oldSpeech=preferences.url(forKey:"modelRoot")?.appendingPathComponent(speechID)
let speechSource = oldSpeech.flatMap { fm.fileExists(atPath:$0.appendingPathComponent("model.onnx").path) ? $0 : nil } ?? resources.appendingPathComponent(speechID)
if fm.fileExists(atPath:speechSource.appendingPathComponent("model.onnx").path) {
 try copyChecked(speechSource,root.appendingPathComponent(speechID))
 print("PASS speech migration: all copied files match SHA-256")
}
let saved=preferences.url(forKey:"translationFolder")
let translationSource=saved.flatMap { fm.fileExists(atPath:$0.appendingPathComponent("model/model.bin").path) ? $0 : nil } ?? resources.appendingPathComponent("en-ru")
if fm.fileExists(atPath:translationSource.appendingPathComponent("model/model.bin").path) {
 let target=root.appendingPathComponent("Translation/migrated-en-ru")
 try copyChecked(translationSource,target)
 preferences.set(target,forKey:"translationFolder");preferences.set(true,forKey:"externalTranslationModel")
 print("PASS translation migration: all copied files match SHA-256")
}
preferences.set(root,forKey:"modelRoot");preferences.set(true,forKey:"externalSpeechModels")
preferences.synchronize()
print(root.path)
