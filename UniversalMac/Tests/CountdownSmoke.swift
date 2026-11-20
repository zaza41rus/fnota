import AppKit
@main struct CountdownSmoke {
 @MainActor static func main() {
  var now:TimeInterval=1000
  let controller=SleepController(clock:{now})
  controller.refreshRunningApplications()
  guard let application=controller.runningApplications.first else { fatalError("Need a running application") }
  controller.selectApplication(application);precondition(controller.active && controller.durationStep==121)
  controller.setTimedDuration(1)
  precondition(controller.applicationID.isEmpty)
  precondition(controller.active && controller.remainingSeconds==60 && controller.countdownLabel=="1:00")
  now += 10;controller.checkConditions()
  precondition(controller.remainingSeconds==50 && controller.countdownLabel=="0:50")
  controller.selectApplication(.init(id:"test.nonexistent",name:"Closed test app",icon:nil))
  precondition(controller.enabled && controller.durationStep==1 && controller.remainingSeconds==50)
  now += 49;controller.checkConditions();precondition(controller.enabled && controller.remainingSeconds==1)
  now += 1;controller.checkConditions()
  precondition(!controller.enabled && !controller.active && controller.durationStep==0 && controller.remainingSeconds==nil)
  print("PASS countdown, app choice/exit cannot override timer, expiry disables mode and releases assertions")
 }
}
