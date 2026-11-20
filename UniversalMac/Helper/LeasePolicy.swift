import Foundation
struct LidLease:Codable {
 let pid:Int32
 let expires:Double
 let active:Bool
 func valid(now:Double,processIsValid:Bool) -> Bool {
  active && pid>1 && expires>now && expires<=now+15 && processIsValid
 }
}
// Journaling precedes the global setting change, so a helper restart can restore it.
final class LidSettingSession {
 private(set) var previous:Int?
 let read:()->Int?
 let apply:(Int)->Bool
 let persist:(Int)->Bool
 let clear:()->Void
 init(recovered:Int?=nil,read:@escaping ()->Int?,apply:@escaping (Int)->Bool,persist:@escaping (Int)->Bool,clear:@escaping ()->Void) {
  previous=recovered;self.read=read;self.apply=apply;self.persist=persist;self.clear=clear
 }
 func enable() -> String? {
  if previous==nil {
   guard let value=read(),value==0 || value==1 else { return "readFailed" }
   guard persist(value) else { return "journalFailed" }
   previous=value
  }
  if read() != 1 { guard apply(1) else { return "enableFailed" } }
  return read()==1 ? nil : "enableFailed"
 }
 func restore() -> Bool {
  guard let value=previous else { return true }
  guard apply(value),read()==value else { return false }
  clear();previous=nil;return true
 }
}
