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
 func start() async throws {
  guard await AVCaptureDevice.requestAccess(for:.audio) else { throw AppFailure.message("Allow microphone access in macOS Settings.") }
  let node = engine.inputNode; let format = node.outputFormat(forBus:0)
  guard format.sampleRate > 0,format.channelCount > 0 else { throw AppFailure.message("Microphone unavailable") }
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
  let file = try AVAudioFile(forWriting:url,settings:format.settings)
  try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
  let sink = AudioWriter(file:file); writer = sink; recordingURL = url
  node.installTap(onBus:0,bufferSize:4096,format:format,block:Self.tap(sink))
  do { try outputMute.begin(); try engine.start() } catch { outputMute.restore(); node.removeTap(onBus:0); writer = nil; try? FileManager.default.removeItem(at:url); throw error }
 }
 func restoreOutput() { outputMute.restore() }
 func stop() throws -> URL {
  engine.stop(); engine.inputNode.removeTap(onBus:0); outputMute.restore()
  let error = writer?.failure; writer = nil
  guard let url = recordingURL else { throw AppFailure.message("Recording has not started") }; recordingURL = nil
  if let error { try? FileManager.default.removeItem(at:url); throw error }
  return url
 }
}
