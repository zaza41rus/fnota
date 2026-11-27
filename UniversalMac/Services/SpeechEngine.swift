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
  guard descriptor.dictationMode == .afterRecording else { throw AppFailure.message("Unsupported speech model") }
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

/// A session owns the native stream on a single queue. The microphone tap submits
/// owned samples, and finish is enqueued after the tap has been removed.
final class LiveSpeechSession: @unchecked Sendable {
 private let queue = DispatchQueue(label:"local.fnota.live-dictation",qos:.userInitiated)
 private var stream:UnsafeMutableRawPointer?
 private var completed:[String] = []
 private var emitted:[String] = []
 private var lastPublished:[String] = []
 private var sampleRate:Int32?
 private var padsOnFinish = false
 private let onUpdate:@Sendable ([String]) -> Void

 init(onUpdate:@escaping @Sendable ([String]) -> Void) { self.onUpdate = onUpdate }
 deinit { if let stream { UMDestroyLiveSpeech(stream) } }

 func prepare(model:SpeechModel,folder:URL) -> AsyncThrowingStream<Void,Error> {
  let (ready,continuation) = AsyncThrowingStream<Void,Error>.makeStream()
  queue.async {
   guard model.dictationMode == .live,
         model.files.allSatisfy({ FileManager.default.isReadableFile(atPath:folder.appendingPathComponent($0.name).path) }) else {
    continuation.finish(throwing:AppFailure.message("Could not load the live dictation model"))
    return
   }
   self.padsOnFinish = model.id == SpeechModel.tOne.id
   if self.padsOnFinish {
    self.stream = folder.appendingPathComponent("model.onnx").path.withCString { modelPath in
     folder.appendingPathComponent("tokens.txt").path.withCString { UMCreateTOneStream(modelPath,$0) }
    }
   } else {
    self.stream = folder.appendingPathComponent("v4_rnnt_640ms_stream_step.int8.onnx").path.withCString { encoder in
     folder.appendingPathComponent("v4_rnnt_640ms_e2e_decoder.onnx").path.withCString { decoder in
      folder.appendingPathComponent("v4_rnnt_640ms_e2e_joint.onnx").path.withCString { joiner in
       folder.appendingPathComponent("tokens.e2e.txt").path.withCString { UMCreateGigaAMV4Stream(encoder,decoder,joiner,$0) }
      }
     }
    }
   }
   if self.stream != nil { continuation.yield(()); continuation.finish() }
   else { continuation.finish(throwing:AppFailure.message("Could not load the live dictation model")) }
  }
  return ready
 }

 func accept(_ buffer:AVAudioPCMBuffer) {
  guard let channels = buffer.floatChannelData,buffer.frameLength > 0 else { return }
  let channelCount = Int(buffer.format.channelCount)
  let rate = Int32(buffer.format.sampleRate.rounded())
  var mono = [Float](repeating:0,count:Int(buffer.frameLength))
  for channel in 0..<channelCount {
   for index in mono.indices { mono[index] += channels[channel][index] / Float(channelCount) }
  }
  let samples = mono
  queue.async {
   self.sampleRate = rate
   self.decode(samples,rate:rate,finished:false)
   let words = self.completed + self.emitted
   if words.count > self.lastPublished.count {
    self.lastPublished = words
    self.onUpdate(words)
   }
  }
 }

 func finish() async -> [String] {
  await withCheckedContinuation { continuation in
   queue.async {
    if let rate = self.sampleRate {
     self.decode([Float](repeating:0,count:self.padsOnFinish ? Int(rate) : 0),rate:rate,finished:true)
    }
    if let stream = self.stream { UMDestroyLiveSpeech(stream); self.stream = nil }
    continuation.resume(returning:self.completed)
   }
  }
 }

 private func decode(_ samples:[Float],rate:Int32,finished:Bool) {
  guard let stream else { return }
  var endpoint:Int32 = 0
  let result = samples.withUnsafeBufferPointer {
   UMDecodeLiveSpeech(stream,$0.baseAddress,Int32($0.count),rate,finished ? 1 : 0,&endpoint)
  }
  let words:[String]
  if let result {
   words = String(cString:result).split(whereSeparator:\.isWhitespace).map(String.init)
   UMFree(result)
  } else { words = [] }

  // A following word establishes the boundary in cumulative output.
  // Keep the word currently being decoded provisional.
  let stable = endpoint != 0 ? words.count : max(0,words.count - 1)
  if stable > emitted.count {
   let extensionWords = words[emitted.count..<stable]
   emitted.append(contentsOf:extensionWords)
  }
  if endpoint != 0 {
   completed.append(contentsOf:emitted)
   emitted.removeAll()
  }
 }
}
