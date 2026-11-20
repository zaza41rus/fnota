import Foundation
@main struct FnGestureSmoke {
 static func main() {
  var g=FnGesture()
  g.press(at:0);precondition(g.release(at:0.08).isEmpty,"single tap must not record")
  g.press(at:0.20);precondition(g.release(at:0.28)==[.translate],"double tap translates only")
  g.press(at:1);precondition(g.advance(at:1.1).isEmpty)
  precondition(g.advance(at:1.23)==[.voiceDown]);precondition(g.advance(at:1.5).isEmpty)
  precondition(g.release(at:2)==[.voiceUp],"release stops dictation")
  g.press(at:3);_ = g.release(at:3.05);g.press(at:4)
  precondition(g.release(at:4.08).isEmpty,"slow taps must not translate")
  g.press(at:4.2);precondition(g.advance(at:4.43)==[.voiceDown],"held second press is voice")
  precondition(g.release(at:5)==[.voiceUp])
  g.press(at:6);precondition(g.advance(at:6.23)==[.voiceDown]);precondition(g.reset()==[.voiceUp]);precondition(g.release(at:6.3).isEmpty)
  g.press(at:7);precondition(g.release(at:7.3)==[.voiceDown,.voiceUp],"delayed timer must not misclassify hold")
  g.press(at:8);_ = g.release(at:8.05);_ = g.reset();g.press(at:8.1);precondition(g.release(at:8.15).isEmpty,"reset clears pending double tap")
  print("PASS: single tap, double tap, hold, repeat, slow taps, held second press, cancellation and delayed timer")
 }
}
