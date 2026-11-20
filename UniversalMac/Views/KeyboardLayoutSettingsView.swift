import SwiftUI
import AppKit
import ApplicationServices
import Carbon

struct KeyboardLayoutSettingsView: View {
 @Bindable var state: AppState

 var body: some View {
  Form {
   Section {
    Toggle("Automatically switch keyboard layouts", isOn:$state.autoSwitchKeyboardLayout).toggleStyle(.switch)
    Text("Corrects a recognized word after Space. Press Esc immediately to undo.")
     .font(.callout).foregroundStyle(.secondary)
    if state.keyboardLayoutNames.count == 2 {
     LabeledContent("Active pair",value:state.keyboardLayoutNames.joined(separator:" ↔ "))
    } else {
     Text("Enable keyboard layouts for exactly two languages in macOS Keyboard settings.")
      .font(.callout).foregroundStyle(.secondary)
    }
    if state.autoSwitchKeyboardLayout && !state.keyboardLayoutSwitcherRunning {
     if state.keyboardLayoutSwitcherPausedForRuSwitcher {
      Text("Automatic switching is paused while RuSwitcher is running.")
       .font(.callout).foregroundStyle(.secondary)
     } else if !accessibility {
      Button("Allow Accessibility…") {
       AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt":true] as CFDictionary)
       open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
      }
     } else {
      Text("If switching is unavailable, allow fnota in Input Monitoring and reopen the app.")
       .font(.callout).foregroundStyle(.secondary)
      Button("Open Input Monitoring") {
       open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
      }
     }
    }
   } header: { Text("Keyboard layout") }
  }
  .formStyle(.grouped)
  .onAppear { state.refreshKeyboardLayoutSwitcher() }
  .onReceive(DistributedNotificationCenter.default().publisher(for:Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String))) { _ in
   Task { @MainActor in state.refreshKeyboardLayoutSwitcher() }
  }
  .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
   state.refreshKeyboardLayoutSwitcher()
  }
 }

 private var accessibility: Bool { AXIsProcessTrusted() }

 private func open(_ url: String) {
  if let url = URL(string: url) { NSWorkspace.shared.open(url) }
 }
}
