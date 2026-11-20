import Foundation
@main struct ClosedLidLeaseSmoke {
 static func main() {
  let lease=LidLease(pid:123,expires:108,active:true)
  precondition(lease.valid(now:100,processIsValid:true))
  precondition(!lease.valid(now:108,processIsValid:true)) // Expired heartbeat / hang.
  precondition(!lease.valid(now:100,processIsValid:false)) // Crash / different process.
  precondition(!lease.valid(now:90,processIsValid:true)) // Clock rollback / invalid long lease.
  precondition(!LidLease(pid:123,expires:108,active:false).valid(now:100,processIsValid:true)) // Stop / timer.
  precondition(!LidLease(pid:1,expires:108,active:true).valid(now:100,processIsValid:true))
  var setting=0,journal:Int?,allowWrites=true
  let session=LidSettingSession(read:{setting},apply:{ value in if !allowWrites { return false };setting=value;return true },persist:{ journal=$0;return true },clear:{journal=nil})
  precondition(session.enable()==nil && setting==1 && journal==0)
  precondition(session.enable()==nil && journal==0) // Heartbeats do not replace baseline.
  allowWrites=false;precondition(!session.restore() && journal==0) // Retry restoration later.
  allowWrites=true;precondition(session.restore() && setting==0 && journal==nil)
  setting=1;precondition(session.enable()==nil && journal==1)
  precondition(session.restore() && setting==1) // Preserve an existing override.
  setting=1;journal=0
  let recovered=LidSettingSession(recovered:journal,read:{setting},apply:{setting=$0;return true},persist:{journal=$0;return true},clear:{journal=nil})
  precondition(recovered.restore() && setting==0 && journal==nil)
  print("PASS restoration, original setting, crash journal and failed-write retry")
  print("PASS bounded lease, expiry, process death, clock change and session stop")
 }
}
