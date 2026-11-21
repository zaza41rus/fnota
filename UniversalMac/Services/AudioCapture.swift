import AVFoundation
final class AudioWriter: @unchecked Sendable {
 let file: AVAudioFile
 let lock = NSLock()
 var failure: Error?
 init(file:AVAudioFile) { self.file = file }
 func append(_ buffer:AVAudioPCMBuffer) { lock.lock(); defer { lock.unlock() }; do { try file.write(from:buffer) } catch { failure = error } }
}
@MainActor final class AudioCapture {
 private let engine = AVAudioEngine()
 private let outputMute = OutputMute()
 private var writer: AudioWriter?
 private var recordingURL: URL?
 nonisolated private static func tap(_ sink:AudioWriter) -> AVAudioNodeTapBlock {
  { buffer,_ in sink.append(buffer) }
 }
 nonisolated private static func liveTap(_ session:LiveSpeechSession) -> AVAudioNodeTapBlock {
  { buffer,_ in session.accept(buffer) }
 }
 nonisolated private static func meteredTap(
  _ sink:@escaping AVAudioNodeTapBlock,level:@escaping @Sendable (Float)->Void
 ) -> AVAudioNodeTapBlock {
  { buffer,time in
   sink(buffer,time)
   guard let channel = buffer.floatChannelData?[0],buffer.frameLength > 0 else { return }
   let frames = Int(buffer.frameLength)
   // Favor the loudest short slice so a consonant or syllable is not buried
   // in the average level of the entire microphone buffer.
   var totalPower:Float = 0
   var loudest:Float = 0
   let slice = max(8,frames/4)
   for start in stride(from:0,to:frames,by:slice) {
    let end = min(frames,start+slice)
    var sum:Float = 0
    var count = 0
    for index in stride(from:start,to:end,by:8) {
     let sample = channel[index]
     sum += sample*sample
     count += 1
    }
    let power = sum/Float(count)
    totalPower += power * Float(end-start)
    loudest = max(loudest,power)
   }
   let power = 0.25*totalPower/Float(frames) + 0.75*loudest
   let decibels = 10*log10(max(power,1e-8))
   level(max(0,min(1,(decibels+55)/37)))
  }
 }
 func start(live:LiveSpeechSession? = nil,level:@escaping @Sendable (Float)->Void) async throws {
  guard await AVCaptureDevice.requestAccess(for:.audio) else { throw AppFailure.message("Allow microphone access in macOS Settings.") }
  let node = engine.inputNode; let format = node.outputFormat(forBus:0)
  guard format.sampleRate > 0,format.channelCount > 0 else { throw AppFailure.message("Microphone unavailable") }
  let block:AVAudioNodeTapBlock
  if let live {
   block = Self.liveTap(live)
  } else {
   let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
   let file = try AVAudioFile(forWriting:url,settings:format.settings)
   do { try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path) }
   catch { try? FileManager.default.removeItem(at:url); throw error }
   let sink = AudioWriter(file:file)
   writer = sink
   recordingURL = url
   block = Self.tap(sink)
  }
  node.installTap(onBus:0,bufferSize:live == nil ? 4096 : 2048,format:format,block:Self.meteredTap(block,level:level))
  do { try outputMute.begin(); try engine.start() }
  catch {
   stopCapture()
   writer = nil
   if let recordingURL { try? FileManager.default.removeItem(at:recordingURL) }
   recordingURL = nil
   throw error
  }
 }
 func stopCapture() {
  engine.stop()
  engine.inputNode.removeTap(onBus:0)
  outputMute.restore()
 }
 func restoreOutput() { outputMute.restore() }
 func stop() throws -> URL {
  stopCapture()
  let error = writer?.failure; writer = nil
  guard let url = recordingURL else { throw AppFailure.message("Recording has not started") }; recordingURL = nil
  if let error { try? FileManager.default.removeItem(at:url); throw error }
  return url
 }
}
