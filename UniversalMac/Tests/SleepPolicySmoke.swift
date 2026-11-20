import Foundation
@main struct SleepPolicySmoke {
 @MainActor static func main() {
  precondition(!SleepController.shouldAssert(enabled:false,deadline:nil,now:0,applicationID:"",runningIDs:[]))
  precondition(!SleepController.shouldAssert(enabled:true,deadline:10,now:10,applicationID:"",runningIDs:[]))
  precondition(!SleepController.shouldAssert(enabled:true,deadline:nil,now:0,applicationID:"test",runningIDs:[]))
  precondition(SleepController.shouldAssert(enabled:true,deadline:nil,now:0,applicationID:"test",runningIDs:["test"]))
  let controller=SleepController();controller.applicationID="test.nonexistent";controller.durationStep=121;controller.start()
  precondition(!controller.enabled && !controller.active)
  controller.refreshRunningApplications()
  guard let application=controller.runningApplications.first else { fatalError("Need a running GUI app") }
  controller.selectApplication(application);precondition(controller.active && controller.enabled && controller.durationStep==121)
  controller.setTimedDuration(30);precondition(controller.applicationID.isEmpty && controller.enabled && controller.durationStep==30)
  controller.setDuration(0);precondition(!controller.enabled && !controller.active)
  print("PASS timer expiry policy, disabled state, app selection enables infinity, app exit stops mode, real assertions acquired and released")
 }
}
