import Foundation
import NaturalLanguage
#if SWIFT_PACKAGE
import NativeCore
#endif
protocol TranslationEngine:Sendable { func translate(_ text:String,folder:URL) async throws -> String }
actor LocalTranslationEngine:TranslationEngine {
 private var handle:UnsafeMutableRawPointer?
 private var bpe:BPETokenizer?
 private var loadedFolder:URL?
 private var cache:[String:String] = [:]
 func unload() { if let handle { UMDestroyTranslator(handle) }; handle = nil; bpe=nil; loadedFolder = nil; cache.removeAll() }
 func translate(_ text:String,folder:URL) async throws -> String {
  let model = folder.appendingPathComponent("model"); let spm = folder.appendingPathComponent("sentencepiece.model")
  guard FileManager.default.fileExists(atPath:model.appendingPathComponent("model.bin").path),(FileManager.default.fileExists(atPath:spm.path) || FileManager.default.fileExists(atPath:folder.appendingPathComponent("bpe.model").path)) else { unload(); throw AppFailure.message("Translation model not found or its disk is disconnected") }
  if loadedFolder != folder {
   unload()
   if FileManager.default.fileExists(atPath:spm.path) {
    handle = model.path.withCString { m in spm.path.withCString { s in UMCreateTranslator(m,s) } }
   } else {
    let info=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("metadata.json"))) as? [String:Any]
    bpe=try BPETokenizer(file:folder.appendingPathComponent("bpe.model"),source:info?["from_code"] as? String ?? "en",target:info?["to_code"] as? String ?? "en")
    handle=model.path.withCString { UMCreateTranslator($0,nil) }
   }
   guard handle != nil else { throw AppFailure.message("Could not load the translation model") }; loadedFolder = folder
  }
  if let cached = cache[text] { return cached }
  guard let handle else { throw AppFailure.message("Model is not loaded") }
  let tokenizer = NLTokenizer(unit:.sentence); tokenizer.string = text
  var segments:[String] = []
  tokenizer.enumerateTokens(in:text.startIndex..<text.endIndex) { range,_ in segments.append(String(text[range])); return true }
  if segments.isEmpty { return text }
  var result:[String] = []
  for sentence in segments {
   try Task.checkCancellation()
   guard sentence.count <= 4000 else { throw AppFailure.message("Selection too long; select a smaller part") }
   let encoded=bpe?.encode(sentence).joined(separator:"\n") ?? sentence
   guard let raw = encoded.withCString({ bpe == nil ? UMTranslate(handle,$0) : UMTranslateTokens(handle,$0) }) else { throw AppFailure.message("Local translation failed") }
   let output=String(cString:raw)
   result.append(bpe?.decode(output.components(separatedBy:"\n")) ?? output); UMFree(raw)
  }
  let joined = result.joined(separator:" ")
  if cache.count > 1000 { cache.removeAll() }; cache[text] = joined
  return joined
 }
}
