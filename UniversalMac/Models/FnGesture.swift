import Foundation
// Pure timing/state machine: a quick tap never starts audio; a held second press is dictation.
struct FnGesture {
 enum Action:Equatable { case voiceDown,voiceUp,translate }
 static let holdDelay:TimeInterval = 0.22
 static let doubleInterval:TimeInterval = 0.35
 private var pressedAt:TimeInterval?
 private var firstRelease:TimeInterval?
 private var secondTap = false
 private var holding = false
 mutating func press(at now:TimeInterval) {
  guard pressedAt == nil else { return }
  secondTap = firstRelease.map { now >= $0 && now - $0 <= Self.doubleInterval } ?? false
  firstRelease = nil; pressedAt = now
 }
 mutating func advance(at now:TimeInterval)->[Action] {
  guard let pressedAt,!holding,now-pressedAt >= Self.holdDelay else { return [] }
  holding = true;secondTap = false;return [.voiceDown]
 }
 mutating func release(at now:TimeInterval)->[Action] {
  guard let start=pressedAt else { return [] };pressedAt=nil
  if holding { holding=false;secondTap=false;firstRelease=nil;return [.voiceUp] }
  if now-start >= Self.holdDelay { secondTap=false;firstRelease=nil;return [.voiceDown,.voiceUp] }
  if secondTap { secondTap=false;firstRelease=nil;return [.translate] }
  firstRelease=now;return []
 }
 mutating func reset()->[Action] { let result:[Action]=holding ? [.voiceUp]:[];self=Self();return result }
}
