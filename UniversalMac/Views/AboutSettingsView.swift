import SwiftUI
import AppKit
struct AboutSettingsView:View {
 @Bindable var state:AppState
 var body:some View {
  ScrollView {
   VStack(alignment:.leading,spacing:20) {
   aboutSection("How it works", "Hold fn to record speech. Release it to recognize and insert text at the cursor; the result is also copied to the clipboard. Mac audio is muted during recording and restored afterwards.")
   aboutSection("Browser translation", "Double-press fn to translate selected text in Safari or Chrome. Without a selection, the page is translated. Repeat the gesture to restore the original. Translation languages depend on the installed models.")
   aboutSection("Privacy and data", "Speech recognition and translation run on your Mac after models are downloaded. Recorded audio and translated text are not sent to a cloud AI service. Temporary microphone recordings are deleted after recognition. Dictated text stays in the system clipboard until it is replaced or cleared.")
   aboutSection("Permissions", "Microphone access is needed for recording. Accessibility allows global keyboard gestures and insertion into other apps. Browser translation needs Automation access and JavaScript from Apple Events enabled in the browser. You can revoke these permissions in macOS Settings.")
   aboutSection("Models and internet", "Internet access is used to fetch model catalogs and download models from third-party sources. Downloads are checked against SHA-256 checksums. You can switch or delete models in the Dictation and Text translation tabs; model licenses differ.")
   aboutSection("Keep macOS awake", "Keep Awake includes working with the lid closed. On first use, macOS asks for administrator approval to install the system helper. This temporarily disables system sleep, including lid-triggered and manual sleep. A timer, session end, low battery, high temperature or a lost connection to fnota restores the previous sleep setting. Manual locking and password settings are unchanged.")
   aboutSection("Limitations", "Recognition and translation can contain errors. Check important text before using it. Large models require more disk space, memory and processing time. This local build is ad-hoc signed and is not notarized by Apple.")
   }.frame(maxWidth:.infinity,alignment:.leading).padding(24).textSelection(.enabled)
  }
 }
 private func aboutSection(_ title:LocalizedStringKey,_ body:LocalizedStringKey) -> some View {
  VStack(alignment:.leading,spacing:3) { Text(title).font(.headline);Text(body).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
 }
}
