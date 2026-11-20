import Foundation
import CoreAudio
@main struct MuteSmoke {
 static func read()->UInt32 {
  var addr=AudioObjectPropertyAddress(mSelector:kAudioHardwarePropertyDefaultOutputDevice,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
  var id=AudioDeviceID(0);var bytes=UInt32(MemoryLayout<AudioDeviceID>.size)
  precondition(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),&addr,0,nil,&bytes,&id)==noErr)
  addr=AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyMute,mScope:kAudioDevicePropertyScopeOutput,mElement:kAudioObjectPropertyElementMain)
  var value:UInt32=0;bytes=4
  precondition(AudioObjectGetPropertyData(id,&addr,0,nil,&bytes,&value)==noErr);return value
 }
 @MainActor static func main() throws {
  let mute=OutputMute();let before=read();defer{mute.restore()}
  try mute.begin();precondition(read()==1,"output must be muted")
  try mute.begin();mute.restore();precondition(read()==before,"restore original mute state")
  mute.restore();precondition(read()==before,"restore idempotent")
  print("PASS: output muted, original state restored, repeated begin/restore safe")
 }
}
