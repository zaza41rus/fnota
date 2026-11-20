import Foundation
import CoreAudio
@MainActor final class OutputMute {
 private struct Saved { let device:AudioDeviceID; let value:UInt32 }
 private var saved:Saved?
 private let recoveryKey = "dictationOutputMuteRecovery"
 init() {
  if let old = UserDefaults.standard.dictionary(forKey:recoveryKey),let device = old["device"] as? UInt32,let value = old["value"] as? UInt32 { saved = Saved(device:device,value:value); restore() }
 }
 private func address()->AudioObjectPropertyAddress { AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyMute,mScope:kAudioDevicePropertyScopeOutput,mElement:kAudioObjectPropertyElementMain) }
 func begin() throws {
  guard saved == nil else { return }
  var selector=AudioObjectPropertyAddress(mSelector:kAudioHardwarePropertyDefaultOutputDevice,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
  var device=AudioDeviceID(0);var size=UInt32(MemoryLayout<AudioDeviceID>.size)
  guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),&selector,0,nil,&size,&device)==noErr,device != 0 else { throw AppFailure.message("Audio output device not found") }
  var property=address();var value:UInt32=0;size=UInt32(MemoryLayout<UInt32>.size)
  guard AudioObjectGetPropertyData(device,&property,0,nil,&size,&value)==noErr else { throw AppFailure.message("Audio device does not support muting") }
  var mute:UInt32=1
  guard AudioObjectSetPropertyData(device,&property,0,nil,size,&mute)==noErr else { throw AppFailure.message("Could not mute Mac audio") }
  saved=Saved(device:device,value:value)
  UserDefaults.standard.set(["device":device,"value":value],forKey:recoveryKey)
 }
 func restore() {
  guard let saved else { return };self.saved=nil
  var property=address();var value=saved.value
  if AudioObjectSetPropertyData(saved.device,&property,0,nil,UInt32(MemoryLayout<UInt32>.size),&value)==noErr { UserDefaults.standard.removeObject(forKey:recoveryKey) }
 }
}
