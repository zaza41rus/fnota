import Foundation
import AVFoundation
#if SWIFT_PACKAGE
import NativeCore
#endif
protocol SpeechEngine: Sendable { func transcribe(file:URL,modelFolder:URL) async throws -> String }
actor GigaAMEngine: SpeechEngine {
 func transcribe(file:URL,modelFolder:URL) async throws -> String {
  let model = modelFolder.appendingPathComponent("model.onnx"); let tokens = modelFolder.appendingPathComponent("tokens.txt")
  guard FileManager.default.fileExists(atPath:model.path), FileManager.default.fileExists(atPath:tokens.path) else { throw AppFailure.message("Dictation model not installed or its disk is disconnected") }
  guard let descriptor=SpeechModel.catalog.first(where:{$0.id==modelFolder.lastPathComponent}) else { throw AppFailure.message("Unsupported speech model") }
  for file in descriptor.files {
   guard FileManager.default.fileExists(atPath:modelFolder.appendingPathComponent(file.name).path) else { throw AppFailure.message("Dictation model not installed or its disk is disconnected") }
  }
  let input = try AVAudioFile(forReading:file)
  guard input.length >= AVAudioFramePosition(input.processingFormat.sampleRate * 0.1) else { throw AppFailure.message("Recording too short") }
  // Bound inference memory, not recording duration. Recordings remain on disk until release.
  let capacity = AVAudioFrameCount(input.processingFormat.sampleRate * 25)
  try Task.checkCancellation()
  guard let recognizer=modelFolder.path.withCString({ UMCreateSpeechRecognizer($0,descriptor.architecture.rawValue) }) else { throw AppFailure.message("Could not load the speech model; check compatibility and model files") }
  defer { UMDestroySpeechRecognizer(recognizer) }
  var output:[String] = []
  while input.framePosition < input.length {
   try Task.checkCancellation()
   guard let buffer = AVAudioPCMBuffer(pcmFormat:input.processingFormat,frameCapacity:capacity) else { throw AppFailure.message("Not enough memory for audio") }
   try input.read(into:buffer,frameCount:capacity)
   guard buffer.frameLength > 0 else { break }
   guard let channels = buffer.floatChannelData else { throw AppFailure.message("PCM float audio required") }
   let count = Int(buffer.frameLength);let channelCount = Int(buffer.format.channelCount)
   if count < Int(buffer.format.sampleRate * 0.1) { break }
   var mono = [Float](repeating:0,count:count)
   for i in 0..<count { for c in 0..<channelCount { mono[i] += channels[c][i] / Float(channelCount) } }
   let result=mono.withUnsafeBufferPointer { samples in
    UMTranscribeSpeech(recognizer,samples.baseAddress,Int32(samples.count),Int32(buffer.format.sampleRate))
   }
   guard let result else { throw AppFailure.message("Could not load the speech model; check compatibility and model files") }
   let text = String(cString:result).trimmingCharacters(in:.whitespacesAndNewlines);UMFree(result)
   if !text.isEmpty { output.append(text) }
  }
  return output.joined(separator:" ")
 }
}
