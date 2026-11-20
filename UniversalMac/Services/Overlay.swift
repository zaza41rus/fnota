import Foundation
// Status belongs in the main window and menu bar; never display dictated text in a floating panel.
@MainActor final class Overlay {
 var onStatus:((String)->Void)?
 func show(_ text:String,persistent:Bool = false) { onStatus?(text) }
 func hide() {}
}
