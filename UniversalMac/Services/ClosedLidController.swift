import AppKit
import CryptoKit
@MainActor @Observable final class ClosedLidController {
 var enabled=UserDefaults.standard.bool(forKey:"closedLidEnabled")
 var installing=false
 var active=false
 var message=""
 private let uid=getuid()
 private var leaseURL:URL { URL(fileURLWithPath:"/private/var/run/fnota-lid-\(uid)/lease.json") }
 private var statusURL:URL { URL(fileURLWithPath:"/private/var/run/fnota-lid-status-\(uid).json") }
 var installed:Bool {
  guard let a=try? FileManager.default.attributesOfItem(atPath:"/Library/PrivilegedHelperTools/local.fnota.lid") else { return false }
  return (a[.ownerAccountID] as? NSNumber)?.intValue==0 && ((a[.posixPermissions] as? NSNumber)?.intValue ?? 0)&0o022==0
 }
 private func save(_ value:Bool) { enabled=value;UserDefaults.standard.set(value,forKey:"closedLidEnabled") }
 func request(_ awake:Bool,remaining:TimeInterval?=nil) {
  guard installed else { active=false;return }
  let data=try? JSONSerialization.data(withJSONObject:["pid":getpid(),"expires":Date().timeIntervalSince1970+min(8,max(0,remaining ?? 8)),"active":enabled && awake])
  do { if let data { try data.write(to:leaseURL,options:.atomic) } }
  catch { active=false;message=L("Closed-lid helper is unavailable. Reinstall it from this option.");return }
  if let data=try? Data(contentsOf:statusURL),let status=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let updated=status["updated"] as? Double,Date().timeIntervalSince1970-updated<8 {
   active=(status["active"] as? Bool ?? false) && enabled && awake
   if let error=status["error"] as? String,!error.isEmpty { message=L("Closed-lid mode could not be applied or restored. Open this option and try again.") }
   else { message="" }
  } else { active=false;message=L("Waiting for the closed-lid helper…") }
 }
 func uninstall() {
  guard installed,!installing else { return }
  save(false);request(false)
  guard let url=Bundle.main.url(forResource:"uninstall-lid-helper",withExtension:"sh"),let command=try? String(contentsOf:url,encoding:.utf8) else { return }
  installing=true
  Task {
   defer { installing=false }
   let script="do shell script \""+command.replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"\"",with:"\\\"").replacingOccurrences(of:"\n",with:"\\n")+"\" with administrator privileges"
   let error=await Task.detached { () -> String? in
    var error:NSDictionary?;NSAppleScript(source:script)?.executeAndReturnError(&error)
    return error.map { String(describing:$0[NSAppleScript.errorMessage] ?? $0) }
   }.value
   message=error ?? L("Closed-lid helper removed");active=false
  }
 }
 func setEnabled(_ value:Bool,awake:Bool,completion:((Bool)->Void)?=nil) {
  guard !installing else { return }
  if !value { save(false);request(false);return }
  if installed { save(true);request(awake);completion?(true);return }
  let alert=NSAlert();alert.messageText=L("Enable closed-lid mode?")
  alert.informativeText=L("fnota will install a system helper that temporarily prevents sleep even when the lid is closed. macOS will ask for administrator approval. The helper restores the previous sleep setting when the session ends or fnota stops responding. Password and manual lock settings are unchanged.")
  alert.addButton(withTitle:L("Install helper"));alert.addButton(withTitle:L("Cancel"))
  guard alert.runModal() == .alertFirstButtonReturn else { completion?(false);return }
  installing=true
  Task {
   defer { installing=false;completion?(installed && enabled) }
   do {
    guard let source=Bundle.main.url(forResource:"fnota-lid-helper",withExtension:nil) else { throw AppFailure.message("Closed-lid helper is missing from the application") }
    let digest=SHA256.hash(data:try Data(contentsOf:source)).map{String(format:"%02x",$0)}.joined()
    let plist:[String:Any]=["Label":"local.fnota.lid","ProgramArguments":["/Library/PrivilegedHelperTools/local.fnota.lid",String(uid)],"RunAtLoad":true,"KeepAlive":true,"ThrottleInterval":5,"ProcessType":"Background"]
    let encoded=try PropertyListSerialization.data(fromPropertyList:plist,format:.xml,options:0).base64EncodedString()
    func quote(_ s:String)->String { "'"+s.replacingOccurrences(of:"'",with:"'\\''")+"'" }
    let command="""
    set -eu
    /bin/mkdir -p /Library/PrivilegedHelperTools
    stage=$(/usr/bin/mktemp -d /Library/PrivilegedHelperTools/.fnota.XXXXXX)
    trap '/bin/rm -rf "$stage"' EXIT
    /usr/bin/install -o root -g wheel -m 0555 \(quote(source.path)) "$stage/helper"
    /usr/bin/printf '%s  %s\\n' \(quote(digest)) "$stage/helper" | /usr/bin/shasum -a 256 -c - >/dev/null
    /usr/bin/printf '%s' \(quote(encoded)) | /usr/bin/base64 -D > "$stage/service.plist"
    /bin/chmod 0644 "$stage/service.plist"
    /bin/launchctl bootout system/local.fnota.lid >/dev/null 2>&1 || true
    /usr/bin/install -o root -g wheel -m 0555 "$stage/helper" /Library/PrivilegedHelperTools/local.fnota.lid
    /usr/bin/install -o root -g wheel -m 0644 "$stage/service.plist" /Library/LaunchDaemons/local.fnota.lid.plist
    /bin/launchctl bootstrap system /Library/LaunchDaemons/local.fnota.lid.plist
    """
    let script="do shell script \""+command.replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"\"",with:"\\\"").replacingOccurrences(of:"\n",with:"\\n")+"\" with administrator privileges"
    let result:String?=await Task.detached {
     var error:NSDictionary?;NSAppleScript(source:script)?.executeAndReturnError(&error)
     return error.map { String(describing:$0[NSAppleScript.errorMessage] ?? $0) }
    }.value
    if let result { throw AppFailure.message(result) }
    save(true);message=L("Closed-lid helper installed")
   } catch { message=error.localizedDescription }
  }
 }
}
