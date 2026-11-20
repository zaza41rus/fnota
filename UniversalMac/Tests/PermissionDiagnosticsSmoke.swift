import Foundation
@main struct PermissionDiagnosticsSmoke {
 @MainActor static func main() {
  precondition(PermissionDiagnostics.missing(voice:true,translation:true,microphone:true,accessibility:true).isEmpty)
  precondition(PermissionDiagnostics.missing(voice:false,translation:false,microphone:false,accessibility:false).isEmpty)
  precondition(PermissionDiagnostics.missing(voice:false,translation:true,microphone:false,accessibility:true).isEmpty)
  precondition(PermissionDiagnostics.missing(voice:true,translation:false,microphone:false,accessibility:true)==["microphone"])
  precondition(PermissionDiagnostics.missing(voice:false,translation:true,microphone:true,accessibility:false)==["accessibility"])
  let diagnostics=PermissionDiagnostics();diagnostics.refresh(voice:false,translation:false)
  precondition(diagnostics.issues.isEmpty && !diagnostics.busy)
  print("PASS: healthy grants hidden; disabled functions request no permissions; only missing required grants surfaced")
 }
}
