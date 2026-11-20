import SwiftUI
import AppKit
// Settings scenes otherwise inherit the tall preferences toolbar used by TabView.
// These public AppKit properties select native unified window chrome.
struct SettingsWindowStyle:NSViewRepresentable {
 func makeNSView(context:Context) -> Marker { Marker() }
 func updateNSView(_ view:Marker,context:Context) { view.applyStyle() }
 final class Marker:NSView {
  override func viewDidMoveToWindow() { super.viewDidMoveToWindow();applyStyle() }
  func applyStyle() {
   DispatchQueue.main.async { [weak self] in
    guard let window=self?.window else { return }
    window.styleMask.insert([.resizable,.miniaturizable])
    window.toolbarStyle = .unified
    window.title = "fnota"
    window.titleVisibility = .hidden
    window.toolbar?.displayMode = .iconOnly
    if let toolbar=window.toolbar {
     for index in toolbar.items.indices.reversed() where toolbar.items[index].itemIdentifier == .toggleSidebar {
      toolbar.removeItem(at:index)
     }
    }
   }
  }
 }
}
