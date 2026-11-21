import AppKit
import ApplicationServices
@MainActor final class SelectionBridge {
 private var previousApplication:NSRunningApplication?
 private var activationObserver:NSObjectProtocol?
 init() {
  if let app=NSWorkspace.shared.frontmostApplication,app.bundleIdentifier != Bundle.main.bundleIdentifier { previousApplication=app }
  activationObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] note in
   guard let app=note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
   let id=app.processIdentifier
   Task { @MainActor in
    guard let self,let app=NSRunningApplication(processIdentifier:id),app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
    self.previousApplication=app
   }
  }
 }
 static func dismissStatusPanels(_ windows:[NSWindow],keyWindow:NSWindow?)->Bool {
  let panelID=NSUserInterfaceItemIdentifier("UniversalMac.StatusPanel")
  let panels=windows.filter { $0.isVisible && $0.identifier==panelID }
  let hadFocus=keyWindow?.identifier==panelID || (keyWindow==nil && !panels.isEmpty)
  for panel in panels { panel.orderOut(nil) }
  return hadFocus
 }
 func prepareDictationTarget(live:Bool = false) async {
  let panelHadFocus=Self.dismissStatusPanels(NSApp.windows,keyWindow:NSApp.keyWindow)
  // Restore the previous app only when leaving our transient status panel.
  // Fn in Settings keeps that window open and does not activate another app.
  if panelHadFocus,NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier,let previousApplication,!previousApplication.isTerminated {
   previousApplication.activate()
   for _ in 0..<12 {
    if NSWorkspace.shared.frontmostApplication?.processIdentifier == previousApplication.processIdentifier { break }
    try? await Task.sleep(for:.milliseconds(20))
   }
  }
  if live,AXIsProcessTrusted(),let app = NSWorkspace.shared.frontmostApplication {
   let root = AXUIElementCreateApplication(app.processIdentifier)
   switch app.bundleIdentifier {
   case "com.google.Chrome":
    AXUIElementSetAttributeValue(root,"AXEnhancedUserInterface" as CFString,kCFBooleanTrue)
   case "com.openai.codex":
    AXUIElementSetAttributeValue(root,"AXManualAccessibility" as CFString,kCFBooleanTrue)
   default: break
   }
  }
  captureTarget(live:live)
 }
 private(set) var failureReason = ""
 private func focusedElement(_ appPID:pid_t)->AXUIElement? {
  let app = AXUIElementCreateApplication(appPID)
  let system = AXUIElementCreateSystemWide()
  for root in liveTarget ? [app,system] : [system,app] {
   var value:CFTypeRef?
   if AXUIElementCopyAttributeValue(root,kAXFocusedUIElementAttribute as CFString,&value) == .success,let value,CFGetTypeID(value) == AXUIElementGetTypeID() {
    let focused = value as! AXUIElement
    if liveTarget,elementString(focused,kAXSubroleAttribute) != kAXSecureTextFieldSubrole,
       !isTextInput(focused),let editable = axElement(focused,"AXEditableAncestor") { return editable }
    return focused
   }
  }
  return nil
 }
 private func failed(_ reason:String)->Bool { failureReason=reason;NSLog("UMInsertion blocked: %@",reason);return false }
 private var capturedWindowNumber:Int?
 private var secureTarget = false
 private var liveTarget = false
 private func visibleWindows(_ appPID:pid_t)->[[String:Any]] {
  guard let list=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] else { return [] }
  return list.filter { ($0[kCGWindowOwnerPID as String] as? Int)==Int(appPID) && ($0[kCGWindowLayer as String] as? Int)==0 }
 }
 private func windowNumber(_ appPID:pid_t)->Int? { visibleWindows(appPID).first?[kCGWindowNumber as String] as? Int }
 private var capturedWindow:AXUIElement?
 private var capturedIdentifier:String?
 private var capturedPosition:CGPoint?
 private var capturedRole:String?
 private var target: AXUIElement?
 private var pid: pid_t?
 private var selectionValue:CFTypeRef?
 private var capturedText:String?
 private var lastVoiceTarget:AXUIElement?
 private var lastVoiceText:String?
 func captureTarget(live:Bool = false) {
  liveTarget = live
  target = nil; pid = nil; selectionValue = nil; capturedText = nil
  failureReason = "";capturedWindow=nil;capturedWindowNumber=nil;secureTarget=false;capturedIdentifier=nil;capturedPosition=nil;capturedRole=nil
  guard AXIsProcessTrusted() else { _ = failed("Accessibility permission missing");return }
  guard let app = NSWorkspace.shared.frontmostApplication,app.bundleIdentifier != Bundle.main.bundleIdentifier else { _ = failed("Focus is still in fnota");return }
  pid=app.processIdentifier;capturedWindowNumber=windowNumber(app.processIdentifier)
  var window:CFTypeRef?
  AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier),kAXFocusedWindowAttribute as CFString,&window)
  if let window,CFGetTypeID(window)==AXUIElementGetTypeID() { capturedWindow=window as! AXUIElement }
  guard let focused = focusedElement(app.processIdentifier) else { failureReason="Application does not expose its field; using system paste";return }
  var subrole:CFTypeRef?; AXUIElementCopyAttributeValue(focused,kAXSubroleAttribute as CFString,&subrole)
  guard subrole as? String != kAXSecureTextFieldSubrole else { secureTarget=true;_ = failed("Secure field");return }
  target = focused; pid = app.processIdentifier
  capturedIdentifier = elementString(focused,"AXIdentifier") ?? elementString(focused,"AXDOMIdentifier")
  capturedRole = elementString(focused,kAXRoleAttribute)
  capturedPosition = position(focused)
  AXUIElementCopyAttributeValue(focused,kAXSelectedTextRangeAttribute as CFString,&selectionValue)
  capturedText = attributeText(kAXValueAttribute)
 }
 private func elementString(_ element:AXUIElement,_ name:String)->String? {
  var value:CFTypeRef?;guard AXUIElementCopyAttributeValue(element,name as CFString,&value) == .success else { return nil }
  return value as? String
 }
 private func position(_ element:AXUIElement)->CGPoint? {
  var value:CFTypeRef?;guard AXUIElementCopyAttributeValue(element,kAXPositionAttribute as CFString,&value) == .success,let value,CFGetTypeID(value)==AXValueGetTypeID() else { return nil }
  var point=CGPoint.zero;return AXValueGetValue(value as! AXValue,.cgPoint,&point) ? point:nil
 }
 private func sameLogicalField(_ focused:AXUIElement,_ original:AXUIElement,_ pid:pid_t)->Bool {
  if CFEqual(focused,original) { return true }
  guard let capturedWindow else { return false }
  var window:CFTypeRef?
  guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid),kAXFocusedWindowAttribute as CFString,&window) == .success,let window,CFEqual(window,capturedWindow) else { return false }
  if let id=capturedIdentifier,!id.isEmpty {
   return id == (elementString(focused,"AXIdentifier") ?? elementString(focused,"AXDOMIdentifier"))
  }
  guard let role=capturedRole,[kAXTextFieldRole,kAXTextAreaRole,kAXComboBoxRole].contains(role),elementString(focused,kAXRoleAttribute)==role,let before=capturedPosition,let after=position(focused) else { return false }
  return abs(before.x-after.x)<1 && abs(before.y-after.y)<1 && elementString(focused,kAXValueAttribute)==capturedText
 }
 private func attributeText(_ name:String)->String? { guard let target else { return nil };var value:CFTypeRef?;guard AXUIElementCopyAttributeValue(target,name as CFString,&value) == .success else { return nil };return value as? String }
 func selectedText()->String? { attributeText(kAXSelectedTextAttribute) }
 var canInsert:Bool {
  guard let target else { return false };var settable:DarwinBoolean = false
  return AXUIElementIsAttributeSettable(target,kAXSelectedTextAttribute as CFString,&settable) == .success && settable.boolValue
 }
 private func unchangedTarget(requireContent:Bool = true)->Bool {
  guard let target,let pid else { return failed(failureReason.isEmpty ? "No saved input field" : failureReason) }
  guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return failed("The active application changed") }
  guard let focused=focusedElement(pid),sameLogicalField(focused,target,pid) else { return failed("Focus moved to another field") }
  if !requireContent { return true }
  if let capturedText,attributeText(kAXValueAttribute) != capturedText { return false }
  if let selectionValue {
   var current:CFTypeRef?;AXUIElementCopyAttributeValue(target,kAXSelectedTextRangeAttribute as CFString,&current)
   guard let current,CFEqual(current,selectionValue) else { return false }
  }
  return true
 }
 func dictationText(_ text:String)->String {
  guard let capturedText=attributeText(kAXValueAttribute),!capturedText.isEmpty else { return text }
  var liveRange:CFTypeRef?
  if let target { AXUIElementCopyAttributeValue(target,kAXSelectedTextRangeAttribute as CFString,&liveRange) }
  var previous = capturedText
  if let selectionValue=liveRange,CFGetTypeID(selectionValue) == AXValueGetTypeID() {
   var range=CFRange()
   if AXValueGetValue(selectionValue as! AXValue,.cfRange,&range) {
    let end = min(range.location,(capturedText as NSString).length)
    previous = (capturedText as NSString).substring(to:max(0,end))
   }
  }
  return previous.last?.isWhitespace == false && text.first?.isWhitespace == false ? " " + text : text
 }
 private func key(_ code:CGKeyCode,flags:CGEventFlags = [],foreground:Bool = false) {
  let source=CGEventSource(stateID:.privateState)
  let down=CGEvent(keyboardEventSource:source,virtualKey:code,keyDown:true),up=CGEvent(keyboardEventSource:source,virtualKey:code,keyDown:false)
  down?.flags=flags;up?.flags=flags
  if let pid {
   let bundle=NSRunningApplication(processIdentifier:pid)?.bundleIdentifier ?? ""
   if foreground {
    down?.post(tap:.cghidEventTap)
    up?.post(tap:.cghidEventTap)
   } else if ["com.google.Chrome","com.apple.Safari"].contains(bundle) { down?.postToPid(pid);up?.postToPid(pid) }
   else {
    if flags.contains(.maskCommand) { let command=CGEvent(keyboardEventSource:source,virtualKey:55,keyDown:true);command?.flags = .maskCommand;command?.post(tap:.cghidEventTap) }
    down?.post(tap:.cghidEventTap);up?.post(tap:.cghidEventTap)
    if flags.contains(.maskCommand) { let command=CGEvent(keyboardEventSource:source,virtualKey:55,keyDown:false);command?.flags = [];command?.post(tap:.cghidEventTap) }
   }
  }
 }
 private func pasteByMenu(_ appPID:pid_t)->Bool {
  var bar:CFTypeRef?
  guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(appPID),kAXMenuBarAttribute as CFString,&bar) == .success,let bar,CFGetTypeID(bar)==AXUIElementGetTypeID() else { return false }
  func search(_ element:AXUIElement,_ depth:Int)->AXUIElement? {
   guard depth<5 else { return nil }
   if elementString(element,kAXMenuItemCmdCharAttribute)?.lowercased()=="v" {
    var modifiers:CFTypeRef?,enabled:CFTypeRef?
    AXUIElementCopyAttributeValue(element,kAXMenuItemCmdModifiersAttribute as CFString,&modifiers)
    AXUIElementCopyAttributeValue(element,kAXEnabledAttribute as CFString,&enabled)
    if (modifiers as? NSNumber)?.intValue==0,(enabled as? NSNumber)?.boolValue==true { return element }
   }
   var children:CFTypeRef?
   if AXUIElementCopyAttributeValue(element,kAXChildrenAttribute as CFString,&children) == .success,let items=children as? [AXUIElement] {
    for child in items { if let result=search(child,depth+1) { return result } }
   }
   return nil
  }
  guard let item=search(bar as! AXUIElement,0) else { return false }
  return AXUIElementPerformAction(item,kAXPressAction as CFString) == .success
 }
 func insert(_ text:String,pasteFallback:Bool = false,selectInserted:Bool = false)->Bool {
  guard !text.isEmpty else { return false }
  if pasteFallback {
   guard !secureTarget,let pid,NSWorkspace.shared.frontmostApplication?.processIdentifier==pid else { return failed("Application changed or field is secure") }
   guard let capturedWindowNumber,windowNumber(pid)==capturedWindowNumber else { return failed("The active window changed") }
   guard NSPasteboard.general.string(forType:.string)==text else { return failed("The clipboard changed") }
   if let target {
    guard unchangedTarget(requireContent:false) else { return false }
    let role=elementString(target,kAXRoleAttribute) ?? ""
    guard elementString(target,kAXSubroleAttribute) != kAXSecureTextFieldSubrole else { return failed("Secure field") }
    guard ![kAXButtonRole,"AXLink",kAXMenuItemRole].contains(role) else { return failed("Selected element is not an input field") }
    if let lastVoiceTarget,CFEqual(lastVoiceTarget,target),let lastVoiceText,selectedText()?.trimmingCharacters(in:.whitespacesAndNewlines)==lastVoiceText.trimmingCharacters(in:.whitespacesAndNewlines) { key(124) }
    lastVoiceTarget=target
   }
   let bundle=NSRunningApplication(processIdentifier:pid)?.bundleIdentifier ?? ""
   if !["com.google.Chrome","com.apple.Safari"].contains(bundle),pasteByMenu(pid) { failureReason="";lastVoiceText=text;return true }
   key(9,flags:.maskCommand);failureReason="";lastVoiceText=text;return true
  }
  guard unchangedTarget(),let target else { return false }
  if canInsert,AXUIElementSetAttributeValue(target,kAXSelectedTextAttribute as CFString,text as CFString) == .success {
   if let selectionValue,CFGetTypeID(selectionValue) == AXValueGetTypeID() {
    var range = CFRange();let value = selectionValue as! AXValue
    if AXValueGetValue(value,.cfRange,&range) { if selectInserted { range.length = text.utf16.count } else { range.location += text.utf16.count; range.length = 0 }; if let updated = AXValueCreate(.cfRange,&range) { AXUIElementSetAttributeValue(target,kAXSelectedTextRangeAttribute as CFString,updated) } }
   }
   return true
  }
  return false
 }

 private func axElement(_ element:AXUIElement,_ attribute:String)->AXUIElement? {
  var value:CFTypeRef?
  guard AXUIElementCopyAttributeValue(element,attribute as CFString,&value) == .success,
        let value,CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
  return (value as! AXUIElement)
 }

 private func belongsToWebEditor(_ element:AXUIElement)->Bool {
  var node:AXUIElement? = element
  for _ in 0..<16 {
   guard let current = node else { break }
   if elementString(current,kAXRoleAttribute) == "AXWebArea" { return true }
   node = axElement(current,kAXParentAttribute)
  }
  return false
 }

 private func isTextInput(_ element:AXUIElement)->Bool {
  let role = elementString(element,kAXRoleAttribute) ?? ""
  return [kAXTextFieldRole,kAXTextAreaRole,kAXComboBoxRole].contains(role)
 }
 private func actuallyEditable(_ element:AXUIElement)->Bool {
  if isTextInput(element) || canInsert { return true }
  var value:CFTypeRef?
  AXUIElementCopyAttributeValue(element,"AXIsEditable" as CFString,&value)
  return (value as? Bool) == true || axElement(element,"AXEditableAncestor") != nil
 }

 func insertLiveDictation(_ words:String,continuation:Bool) async -> Bool {
  if !continuation,!secureTarget,let pid,
     NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
     let capturedWindow,
     let currentWindow = axElement(AXUIElementCreateApplication(pid),kAXFocusedWindowAttribute),
     CFEqual(capturedWindow,currentWindow),
     target.map({ !actuallyEditable($0) }) ?? true {
   // The renderer may expose its field only after its accessibility tree loads.
   captureTarget(live:true)
  }
  guard !secureTarget,let target,let pid,
        unchangedTarget(requireContent:false),
        elementString(target,kAXSubroleAttribute) != kAXSecureTextFieldSubrole,
        actuallyEditable(target)
  else { return failed("Live dictation has no focused editable field") }

  let bundle = NSRunningApplication(processIdentifier:pid)?.bundleIdentifier ?? ""
  let webEditor = ["com.openai.codex","com.google.Chrome","com.apple.Safari"].contains(bundle) || belongsToWebEditor(target)
  let text = continuation ? " " + words : dictationText(words)
  if !webEditor {
   guard unchangedTarget() else { return failed("Live dictation field or caret was edited") }
   if canInsert,AXUIElementSetAttributeValue(target,kAXSelectedTextAttribute as CFString,text as CFString) == .success {
    if let range = textRange(selectionValue),
       let caret = selection(at:range.location + text.utf16.count) {
     AXUIElementSetAttributeValue(target,kAXSelectedTextRangeAttribute as CFString,caret)
    }
    refreshLiveSelection(target)
    return true
   }
  }
  let activeWindow = axElement(AXUIElementCreateApplication(pid),kAXFocusedWindowAttribute)
  let sameWindow = capturedWindow.flatMap { original in activeWindow.map { CFEqual(original,$0) } }
   ?? (capturedWindowNumber != nil && capturedWindowNumber == windowNumber(pid))
  guard sameWindow else { return failed("The active window changed") }

  let before = attributeText(kAXValueAttribute)
  let beforeRange = textRange(selectionValue)
  let clipboard = NSPasteboard.general
  let saved = (clipboard.pasteboardItems ?? []).map { item in
   item.types.compactMap { type in item.data(forType:type).map { (type,$0) } }
  }
  guard unchangedTarget(requireContent:false) else { return false }
  clipboard.clearContents()
  clipboard.setString(text,forType:.string)
  let pasteChange = clipboard.changeCount
  defer {
   if clipboard.changeCount == pasteChange {
    clipboard.clearContents()
    let items = saved.map { contents in
     let item = NSPasteboardItem()
     for (type,data) in contents { item.setData(data,forType:type) }
     return item
    }.filter { !$0.types.isEmpty }
    if !items.isEmpty { clipboard.writeObjects(items) }
   }
  }

  // Send the shortcut through the foreground responder chain. Chromium and
  // WebKit forward it to the content editor there, including contenteditable.
  key(9,flags:.maskCommand,foreground:true)
  for _ in 0..<8 {
   try? await Task.sleep(for:.milliseconds(25))
   guard unchangedTarget(requireContent:false) else { return false }
   var current:CFTypeRef?
   AXUIElementCopyAttributeValue(target,kAXSelectedTextRangeAttribute as CFString,&current)
   if attributeText(kAXValueAttribute) != before || textRange(current) != beforeRange {
    refreshLiveSelection(target)
    return true
   }
  }
  // Some web inputs report a static or absent AX value and caret. The paste
  // event was dispatched to the still-focused editor.
  if webEditor || (before == nil && beforeRange == nil) { return true }
  return failed("The editor did not accept the live paste")
 }

 private func refreshLiveSelection(_ element:AXUIElement) {
  capturedText = attributeText(kAXValueAttribute)
  var range:CFTypeRef?
  AXUIElementCopyAttributeValue(element,kAXSelectedTextRangeAttribute as CFString,&range)
  selectionValue = range
 }

 private func textRange(_ value:CFTypeRef?)->NSRange? {
  guard let value,CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
  var range = CFRange()
  guard AXValueGetValue(value as! AXValue,.cfRange,&range),range.location >= 0,range.length >= 0 else { return nil }
  return NSRange(location:range.location,length:range.length)
 }

 private func selection(at location:Int)->AXValue? {
  var range = CFRange(location:location,length:0)
  return AXValueCreate(.cfRange,&range)
 }

 func dictationWindowFrame()->NSRect? {
  guard let pid,NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
        let desktopTop = NSScreen.screens.first?.frame.maxY else { return nil }
  let screenRect:CGRect
  if let original = capturedWindow {
   guard let current = axElement(AXUIElementCreateApplication(pid),kAXFocusedWindowAttribute),
         CFEqual(current,original),let origin = position(current) else { return nil }
   var value:CFTypeRef?
   guard AXUIElementCopyAttributeValue(current,kAXSizeAttribute as CFString,&value) == .success,
         let value,CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
   var size = CGSize.zero
   guard AXValueGetValue(value as! AXValue,.cgSize,&size) else { return nil }
   screenRect = CGRect(origin:origin,size:size)
  } else {
   let windows = visibleWindows(pid)
   guard windows.count == 1,let capturedWindowNumber,let info = windows.first,
         (info[kCGWindowNumber as String] as? Int) == capturedWindowNumber,
         let bounds = info[kCGWindowBounds as String] as? [String:Any],
         let rect = CGRect(dictionaryRepresentation:bounds as CFDictionary) else { return nil }
   screenRect = rect
  }
  return NSRect(x:screenRect.minX,y:desktopTop-screenRect.maxY,
                width:screenRect.width,height:screenRect.height)
 }

 func requestAccess() { AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt":true] as CFDictionary) }
}
