import Foundation
import Darwin
import Security
import IOKit.ps

// No shell, arbitrary command, arbitrary path or caller-supplied pmset arguments.
let service="local.fnota.lid"
let args=CommandLine.arguments
if geteuid() != 0 || args.count != 2 { exit(64) }
guard let uid=UInt32(args[1]),uid>=501 else { exit(64) }
let directory="/private/var/run/fnota-lid-\(uid)"
let journal="/private/var/db/fnota-lid-state"
let statusFile="\(directory)/status.json"
let leaseFile="\(directory)/lease.json"
let fm=FileManager.default
umask(0o077)
if mkdir(directory,0o700) != 0 && errno != EEXIST { exit(1) }
var dirStat=stat()
guard lstat(directory,&dirStat)==0,(dirStat.st_mode&S_IFMT)==S_IFDIR else { exit(1) }
// Directory parent is root-owned; only this user's bounded lease is accepted.
if chown(directory,uid,gid_t.max) != 0 { exit(1) }
func pmset(_ value:Int) -> Bool {
 let p=Process();p.executableURL=URL(fileURLWithPath:"/usr/bin/pmset");p.arguments=["-a","disablesleep",String(value)]
 p.standardOutput=FileHandle.nullDevice;p.standardError=FileHandle.nullDevice
 do { try p.run();p.waitUntilExit();return p.terminationStatus==0 } catch { return false }
}
func currentSetting() -> Int? {
 let p=Process(),pipe=Pipe();p.executableURL=URL(fileURLWithPath:"/usr/bin/pmset");p.arguments=["-g"];p.standardOutput=pipe;p.standardError=FileHandle.nullDevice
 do { try p.run();let data=pipe.fileHandleForReading.readDataToEndOfFile();p.waitUntilExit();guard p.terminationStatus==0 else { return nil }
  for line in String(decoding:data,as:UTF8.self).split(separator:"\n") {
   let parts=line.split(whereSeparator:{$0.isWhitespace})
   if parts.count==2,parts[0]=="SleepDisabled",let value=Int(parts[1]),value==0 || value==1 { return value }
  }
 } catch {}
 return nil
}
func writeStatus(_ active:Bool,_ error:String="") {
 let data=try! JSONSerialization.data(withJSONObject:["active":active,"error":error,"updated":Date().timeIntervalSince1970,"version":1])
 // Root status lives outside user-owned lease directory; clients can read only.
 let path="/private/var/run/fnota-lid-status-\(uid).json"
 try? data.write(to:URL(fileURLWithPath:path),options:.atomic);chmod(path,0o644)
}
func readLease() -> LidLease? {
 let fd=open(leaseFile,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);guard fd>=0 else { return nil };defer { close(fd) }
 var st=stat();guard fstat(fd,&st)==0,st.st_uid==uid,(st.st_mode&S_IFMT)==S_IFREG,st.st_size>0,st.st_size<=1024 else { return nil }
 var bytes=[UInt8](repeating:0,count:1024);let count=read(fd,&bytes,1024);guard count>0 else { return nil }
 return try? JSONDecoder().decode(LidLease.self,from:Data(bytes.prefix(count)))
}
func validClient(_ pid:Int32) -> Bool {
 var code:SecCode?
 guard SecCodeCopyGuestWithAttributes(nil,[kSecGuestAttributePid:pid] as CFDictionary,[],&code)==errSecSuccess,let code else { return false }
 var requirement:SecRequirement?
 guard SecRequirementCreateWithString("identifier \"local.safarilocalru.UniversalMac\"" as CFString,[],&requirement)==errSecSuccess,let requirement,
       SecCodeCheckValidity(code,[],requirement)==errSecSuccess else { return false }
 var staticCode:SecStaticCode?
 guard SecCodeCopyStaticCode(code,[],&staticCode)==errSecSuccess,let staticCode else { return false }
 var info:CFDictionary?
 guard SecCodeCopySigningInformation(staticCode,[],&info)==errSecSuccess,let dict=info as? [String:Any],let url=dict[kSecCodeInfoMainExecutable as String] as? URL else { return false }
 return url.resolvingSymlinksInPath().path=="/Applications/fnota.app/Contents/MacOS/UniversalMac"
}
func safeConditions() -> Bool {
 if [.serious,.critical].contains(ProcessInfo.processInfo.thermalState) { return false }
 if let info=IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),let sources=IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
  for source in sources {
   if let d=IOPSGetPowerSourceDescription(info,source)?.takeUnretainedValue() as? [String:Any],d[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue,(d[kIOPSCurrentCapacityKey] as? Int ?? 100)<=10 { return false }
  }
 }
 return true
}
let recovered=fm.contents(atPath:journal).flatMap { String(data:$0,encoding:.utf8) }.flatMap(Int.init)
let session=LidSettingSession(recovered:recovered,read:currentSetting,apply:pmset,persist:{ value in
 do { try Data(String(value).utf8).write(to:URL(fileURLWithPath:journal),options:.atomic);chmod(journal,0o600);return true }
 catch { return false }
},clear:{ try? fm.removeItem(atPath:journal) })
// Recover a previous helper crash before accepting a new session.
if recovered != nil && !session.restore() { writeStatus(false,"restoreFailed");exit(1) }
let signals=DispatchSource.makeSignalSource(signal:SIGTERM,queue:.main)
signal(SIGTERM,SIG_IGN)
signals.setEventHandler { if session.restore() { writeStatus(false);exit(0) } else { writeStatus(false,"restoreFailed");exit(1) } };signals.resume()
let timer=DispatchSource.makeTimerSource(queue:.main)
timer.schedule(deadline:.now(),repeating:2)
timer.setEventHandler {
 let lease=readLease()
 let requested=lease.map { $0.valid(now:Date().timeIntervalSince1970,processIsValid:validClient($0.pid)) } ?? false
 if requested && safeConditions() {
  if let error=session.enable() { writeStatus(false,error);return }
  writeStatus(true)
 } else {
  if session.restore() { writeStatus(false,requested ? "safetyStop" : "") }
  else { writeStatus(false,"restoreFailed") }
 }
}
timer.resume();dispatchMain()
