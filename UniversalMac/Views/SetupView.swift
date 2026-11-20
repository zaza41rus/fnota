import SwiftUI
import AppKit
struct SetupView:View {
 @Bindable var state:AppState
 @Environment(\.dismiss) private var dismiss
 private var step:PermissionDiagnostics.Issue? {
  let priority=["microphone","accessibility","com.google.Chrome","com.apple.Safari"]
  return state.permissions.issues.sorted { (priority.firstIndex(of:$0.id) ?? 99)<(priority.firstIndex(of:$1.id) ?? 99) }.first
 }
 private var title:String {
  switch step?.id {
  case "microphone":return L("Microphone")
  case "accessibility":return L("Text insertion and shortcuts")
  case "com.google.Chrome":return "Google Chrome"
  case "com.apple.Safari":return "Safari"
  default:return L("Permissions")
  }
 }
 var body:some View {
  VStack(alignment:.leading,spacing:18) {
   Text("Permissions").font(.title2.bold())
   if let step {
    Label(title,systemImage:"lock.shield").font(.headline)
    Text(L(step.message)).foregroundStyle(.secondary)
    if step.id=="com.apple.Safari" {
     Text("In Safari, open Safari → Settings… → Developer and turn on ‘Allow JavaScript from Apple Events’. If Developer is hidden, first enable web developer features in Safari → Settings… → Advanced. Return here and click Continue.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
    } else if step.id=="com.google.Chrome" {
     Text("In Chrome, open View → Developer and check ‘Allow JavaScript from Apple Events’ in the window you use for translation. Return here and click Continue.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
    } else {
     Text("Approve the system request or enable access in macOS Settings. Return here to continue automatically.").font(.callout).foregroundStyle(.secondary)
    }
    Spacer()
    HStack {
     Text("\(L("Remaining checks")): \(state.permissions.issues.count)").font(.caption).foregroundStyle(.secondary)
     Spacer()
     if state.permissions.busy { ProgressView().controlSize(.small) }
     else { Button("Continue") { state.permissions.runSetup(voice:state.voiceEnabled,translation:state.translationEnabled) }.buttonStyle(.borderedProminent) }
    }
   } else {
    if state.permissions.busy { ProgressView("Checking permissions…") }
    else { Label("All required permissions are granted",systemImage:"checkmark.circle.fill").foregroundStyle(.green) }
    Spacer()
    HStack { Spacer();Button("Done") { dismiss() }.buttonStyle(.borderedProminent) }
   }
  }
 }
}
