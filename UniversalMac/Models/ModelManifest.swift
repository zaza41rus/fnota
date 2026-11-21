import Foundation
struct ModelFile: Codable, Sendable { let name: String; let remote: String; let sha256: String; let bytes: Int64 }
struct SpeechModel: Codable, Sendable, Identifiable {
 let id: String; let title: String; let license: String; let source: String; let files: [ModelFile]
 enum DictationMode { case afterRecording, live }
 var dictationMode: DictationMode { id == Self.tOne.id ? .live : .afterRecording }
 var dictationModeLabel: String { dictationMode == .live ? "Live dictation" : "Inserts after recording" }
 enum Architecture:Int32 { case ctc=0,whisper=1,parakeet=2,senseVoice=3 }
 var architecture:Architecture {
  if id.hasPrefix("whisper-") { return .whisper }
  if id.hasPrefix("parakeet-") { return .parakeet }
  if id.hasPrefix("sensevoice-") { return .senseVoice }
  return .ctc
 }
 var purpose:String {
  if dictationMode == .live { return "Streams Russian dictation locally and inserts words as you speak." }
  switch architecture {
  case .parakeet:return "Fast multilingual dictation with punctuation. Supports 25 European languages; not intended for Chinese, Japanese or Korean."
  case .senseVoice:return "Fast dictation for Chinese, English, Japanese, Korean and Cantonese. Does not support Russian; subject to the FunASR model license."
  case .whisper:
   if id.contains("tiny-") { return "Smallest multilingual Whisper. Fast and compact; more errors on short or noisy recordings." }
   if id.contains("base-") { return "Compact multilingual Whisper. More capable than Tiny, but may miss words or grammar." }
   if id.contains("small-") { return "Balanced multilingual Whisper. Needs more memory and processing than Base." }
   if id.contains("medium-") { return "Larger multilingual Whisper for better accuracy. Slower and uses more memory than Small." }
   if id.contains("turbo-") { return "Multilingual Whisper optimized for speed. A larger download, with faster decoding than Large v3." }
   return "Largest multilingual Whisper in this catalog. High memory use and the slowest decoding; accuracy still depends on the recording."
  case .ctc:return id == Self.gigaAM.id ? "Russian dictation with punctuation and normalization. Russian only; larger download than Whisper Tiny." : "Russian recognition without built-in punctuation. Useful for plain transcripts; punctuation needs manual editing."
  }
 }
 var sourceURL:URL { URL(string:"https://huggingface.co/"+source.components(separatedBy:" · ")[0])! }
 var language:String {
  switch architecture {
  case .whisper:return "99 languages, including English, Russian, Spanish, Chinese and Korean"
  case .parakeet:return "25 European languages, including English, Russian, Spanish, French and German"
  case .senseVoice:return "Chinese, English, Japanese, Korean and Cantonese"
  case .ctc:return "Russian"
  }
 }
 var size:String { ByteCountFormatter.string(fromByteCount:bytes,countStyle:.file) }
 static var catalog:[SpeechModel] { [.gigaAM,.tOne,.ctc,.whisperTiny]+expanded }
 static let tOne = SpeechModel(id:"t-one-russian-streaming",title:"T-one · Russian",license:"Apache-2.0",source:"csukuangfj/sherpa-onnx-streaming-t-one-russian-2025-09-08 · 9d63341",files:[
 ModelFile(name:"model.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-streaming-t-one-russian-2025-09-08/resolve/9d63341e0f2d8a8b2edaa825aa1fcfe3c5283b47/model.onnx",sha256:"5ded080e2a6c86ecc11bcb0902d77524eb3e8b0844cb0c0754347f5aafb4dabc",bytes:144193702),
 ModelFile(name:"tokens.txt",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-streaming-t-one-russian-2025-09-08/resolve/9d63341e0f2d8a8b2edaa825aa1fcfe3c5283b47/tokens.txt",sha256:"27f7b3ba2096c572375fba1a6b29af1f80d86e08a329940612908112695f97e0",bytes:202)])
 static let whisperTiny = SpeechModel(id:"whisper-tiny-multilingual-int8",title:"Whisper Tiny · multilingual",license:"MIT",source:"csukuangfj/sherpa-onnx-whisper-tiny · 65176e2",files:[
 ModelFile(name:"model.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/65176e2deb88badc814a94058666cadccc29b61c/tiny-encoder.int8.onnx",sha256:"d24fb083ae3b1041fc24e97971d60e280c9342201fbb67b0ab428a8b4a51a434",bytes:12937772),
 ModelFile(name:"decoder.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/65176e2deb88badc814a94058666cadccc29b61c/tiny-decoder.int8.onnx",sha256:"d2fece8dd42771f1df975c6c0445770d0c292bf7547c2cae04a6c0cc57540925",bytes:89855401),
 ModelFile(name:"tokens.txt",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/65176e2deb88badc814a94058666cadccc29b61c/tiny-tokens.txt",sha256:"b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126",bytes:816730)])
 static let ctc = SpeechModel(id:"gigaam-v3-ctc-int8",title:"GigaAM v3 CTC · Russian",license:"MIT",source:"Smirnov75/GigaAM-v3-sherpa-onnx · 6888903",files:[
 ModelFile(name:"model.onnx",remote:"https://huggingface.co/Smirnov75/GigaAM-v3-sherpa-onnx/resolve/6888903da215c7735f51101d939f3bfa679fb2b8/gigaam_v3_ctc_int8.onnx",sha256:"3905685b05941e79772e68acc8af5ac5aafb615fe57a38a719ad3291dbcbf3ed",bytes:319183165),
 ModelFile(name:"tokens.txt",remote:"https://huggingface.co/Smirnov75/GigaAM-v3-sherpa-onnx/resolve/6888903da215c7735f51101d939f3bfa679fb2b8/gigaam_v3_ctc_tokens.txt",sha256:"48c9111eb77c9c42d08ecc71c00c09407ef2cce01195d72b7cc0c3c08ce89213",bytes:195)])
 var bytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
 static let gigaAM = SpeechModel(id:"gigaam-v3-e2e-ctc-int8",title:"GigaAM v3 E2E CTC · Russian",license:"MIT",source:"Smirnov75/GigaAM-v3-sherpa-onnx · 6888903",files:[
 ModelFile(name:"model.onnx",remote:"https://huggingface.co/Smirnov75/GigaAM-v3-sherpa-onnx/resolve/6888903da215c7735f51101d939f3bfa679fb2b8/gigaam_v3_e2e_ctc_int8.onnx",sha256:"0aacb41f70f0f5aaac4b45dd430337b9e16b180f22c72af04db8516e7609c3c0",bytes:319869121),
 ModelFile(name:"tokens.txt",remote:"https://huggingface.co/Smirnov75/GigaAM-v3-sherpa-onnx/resolve/6888903da215c7735f51101d939f3bfa679fb2b8/gigaam_v3_e2e_ctc_tokens.txt",sha256:"f8eb9b115e2748db9c40a5897cae11dd0678cc0b40fd7e25f8c43b3bf28715e4",bytes:2006)])
 static let expanded:[SpeechModel] = [
SpeechModel(id:"whisper-base-multilingual-int8",title:"Whisper Base · multilingual",license:"MIT",source:"csukuangfj/sherpa-onnx-whisper-base · bb53ee2",files:[ModelFile(name:"decoder.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/bb53ee204431c90d314c1cc08d28d23e5b7927cc/base-decoder.int8.onnx",sha256:"9759d217388a01b3a4c7c15533201067b48ae819c4daafc8624e64b9409dc02d",bytes:130672026),ModelFile(name:"model.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/bb53ee204431c90d314c1cc08d28d23e5b7927cc/base-encoder.int8.onnx",sha256:"0b8fb1304b6109976038efff5ace81720e00386f3ff6b54ee8c75291ca0a1e11",bytes:29120534),ModelFile(name:"tokens.txt",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/bb53ee204431c90d314c1cc08d28d23e5b7927cc/base-tokens.txt",sha256:"b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126",bytes:816730)]),
SpeechModel(id:"whisper-small-multilingual-int8",title:"Whisper Small · multilingual",license:"MIT",source:"csukuangfj/sherpa-onnx-whisper-small · 8f3c18b",files:[ModelFile(name:"decoder.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/8f3c18b358db4d1f2fc1eae49d75cd20989e4309/small-decoder.int8.onnx",sha256:"acad50b5c782696e91b55914cc5ab4f756f1532f76e22aa6fc615f39fb69a8ee",bytes:262226114),ModelFile(name:"model.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/8f3c18b358db4d1f2fc1eae49d75cd20989e4309/small-encoder.int8.onnx",sha256:"4cbe7b22fa9026b843b60a68640c747de05bafb1a11b57edc0e66c232d9f33a9",bytes:112442483),ModelFile(name:"tokens.txt",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/8f3c18b358db4d1f2fc1eae49d75cd20989e4309/small-tokens.txt",sha256:"b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126",bytes:816730)]),
SpeechModel(id:"whisper-medium-multilingual-int8",title:"Whisper Medium · multilingual",license:"MIT",source:"csukuangfj/sherpa-onnx-whisper-medium · 8c31d28",files:[ModelFile(name:"decoder.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-medium/resolve/8c31d28503847560985df21f90e14f0c736e075e/medium-decoder.int8.onnx",sha256:"595d00a338a365a7bfa0ca7f296cabc639583bef770ab6130df90f49a6412747",bytes:571059257),ModelFile(name:"model.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-medium/resolve/8c31d28503847560985df21f90e14f0c736e075e/medium-encoder.int8.onnx",sha256:"1c54582b4d829de0089f6cb63bbbdb3bf7555398bacaf855fbecf1a84dfd193e",bytes:374196283),ModelFile(name:"tokens.txt",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-medium/resolve/8c31d28503847560985df21f90e14f0c736e075e/medium-tokens.txt",sha256:"b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126",bytes:816730)]),
SpeechModel(id:"whisper-turbo-multilingual-int8",title:"Whisper Turbo · multilingual",license:"MIT",source:"csukuangfj/sherpa-onnx-whisper-turbo · 2ca6ff6",files:[ModelFile(name:"decoder.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-turbo/resolve/2ca6ff69fc878651b770880507669577ac41c2ff/turbo-decoder.int8.onnx",sha256:"20accd02388482eb3a46bd615631adfdc85e1eb2c7db9ea3f02a40ffe6b81547",bytes:361080764),ModelFile(name:"model.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-turbo/resolve/2ca6ff69fc878651b770880507669577ac41c2ff/turbo-encoder.int8.onnx",sha256:"b02dcdf54f348741e93fe732b67d933c8dcb6735655f710640143081db38878b",bytes:674716297),ModelFile(name:"tokens.txt",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-turbo/resolve/2ca6ff69fc878651b770880507669577ac41c2ff/turbo-tokens.txt",sha256:"b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126",bytes:816730)]),
SpeechModel(id:"whisper-large-v3-multilingual-int8",title:"Whisper Large v3 · multilingual",license:"MIT",source:"csukuangfj/sherpa-onnx-whisper-large-v3 · 2a65070",files:[ModelFile(name:"decoder.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-large-v3/resolve/2a6507094dd6020d939d78e3f1834a1d06267fca/large-v3-decoder.int8.onnx",sha256:"ebc6bfd88e162a46cb3edee8a7e727e1dcbc65cabecb19e2573695e4d495e1af",bytes:1008265203),ModelFile(name:"model.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-large-v3/resolve/2a6507094dd6020d939d78e3f1834a1d06267fca/large-v3-encoder.int8.onnx",sha256:"d531cf17248acc43e8c09b472a0877055e770877857a5332fc1304b36534ec85",bytes:766671985),ModelFile(name:"tokens.txt",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-whisper-large-v3/resolve/2a6507094dd6020d939d78e3f1834a1d06267fca/large-v3-tokens.txt",sha256:"b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126",bytes:816730)]),
SpeechModel(id:"parakeet-v3-int8",title:"Parakeet v3 · multilingual",license:"CC-BY-4.0",source:"csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8 · 2bda32e",files:[ModelFile(name:"decoder.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/2bda32ec70b097a55adaa07d9a7173915b43cc78/decoder.int8.onnx",sha256:"179e50c43d1a9de79c8a24149a2f9bac6eb5981823f2a2ed88d655b24248db4e",bytes:11845275),ModelFile(name:"model.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/2bda32ec70b097a55adaa07d9a7173915b43cc78/encoder.int8.onnx",sha256:"acfc2b4456377e15d04f0243af540b7fe7c992f8d898d751cf134c3a55fd2247",bytes:652184281),ModelFile(name:"joiner.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/2bda32ec70b097a55adaa07d9a7173915b43cc78/joiner.int8.onnx",sha256:"3164c13fc2821009440d20fcb5fdc78bff28b4db2f8d0f0b329101719c0948b3",bytes:6355277),ModelFile(name:"tokens.txt",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/2bda32ec70b097a55adaa07d9a7173915b43cc78/tokens.txt",sha256:"d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d",bytes:93939)]),
SpeechModel(id:"sensevoice-small-int8",title:"SenseVoice Small · multilingual",license:"FunASR Model License 1.1",source:"csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09 · 355f4d4",files:[ModelFile(name:"model.onnx",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09/resolve/355f4d4884d8afd08aef04b9007a8556d7b463b2/model.int8.onnx",sha256:"12ca1a2ae7ecf3e0019ef2822307ee0b5cadc9196569e379b4c4026f8205276d",bytes:237115547),ModelFile(name:"tokens.txt",remote:"https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09/resolve/355f4d4884d8afd08aef04b9007a8556d7b463b2/tokens.txt",sha256:"f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc",bytes:315894)])
 ]
}
enum AppFailure: LocalizedError {
 case message(String)
 var errorDescription: String? { switch self { case .message(let s):L(s) } }
}
