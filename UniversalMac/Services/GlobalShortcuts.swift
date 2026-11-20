import AppKit
import Carbon
@MainActor final class GlobalShortcuts {
 private var refs:[EventHotKeyRef] = []
 private var handler:EventHandlerRef?
 private var fnTap:CFMachPort?
 private var fnSource:CFRunLoopSource?
 private var fnDown = false
 private var fnGesture = FnGesture()
 private var holdTask:Task<Void,Never>?
 private var voiceUsesFn = false
 private var translationUsesFn = false
 private var pressed:Set<UInt32> = []
 var onAction:((UInt32,Bool)->Void)?
 func register(voice:ShortcutBinding,translation:ShortcutBinding,voiceEnabled:Bool=true,translationEnabled:Bool=true) -> [String] {
  unregister()
  var specs = [EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed)),EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyReleased))]
  InstallEventHandler(GetApplicationEventTarget(),{ _,event,context in
   guard let event,let context else { return noErr }
   var id = EventHotKeyID()
   GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&id)
   let shortcut = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
   let action = id.id; let down = GetEventKind(event) == UInt32(kEventHotKeyPressed)
   Task { @MainActor in shortcut.receive(action,down:down) }; return noErr
  },2,&specs,Unmanaged.passUnretained(self).toOpaque(),&handler)
  var errors:[String] = []
  for (id,binding) in [(UInt32(1),voice),(UInt32(2),translation)] {
   if binding.isFn || (id==1 && !voiceEnabled) || (id==2 && !translationEnabled) { continue }
   var ref:EventHotKeyRef?
   let status = RegisterEventHotKey(binding.keyCode,binding.modifiers,EventHotKeyID(signature:0x554d4143,id:id),GetApplicationEventTarget(),0,&ref)
   if status == noErr,let ref { refs.append(ref) } else { errors.append("\(binding.label) is used by another application (\(status))") }
  }
  if (voice.isFn && voiceEnabled) || (translation.isFn && translationEnabled) {
   voiceUsesFn = voice.isFn && voiceEnabled; translationUsesFn = translation.isFn && translationEnabled
   fnTap = CGEvent.tapCreate(tap:.cgSessionEventTap,place:.headInsertEventTap,options:.defaultTap,eventsOfInterest:CGEventMask(1 << CGEventType.flagsChanged.rawValue),callback:{ _,type,event,context in
    guard let context else { return Unmanaged.passUnretained(event) }
    let owner = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
     Task { @MainActor in owner.reenableFn() }; return Unmanaged.passUnretained(event)
    }
    guard event.getIntegerValueField(.keyboardEventKeycode) == 63 else { return Unmanaged.passUnretained(event) }
    let down = event.flags.contains(.maskSecondaryFn);let now = ProcessInfo.processInfo.systemUptime
    Task { @MainActor in owner.fnChanged(down,at:now) }
    return nil
   },userInfo:Unmanaged.passUnretained(self).toOpaque())
   if let fnTap {
    fnSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault,fnTap,0)
    CFRunLoopAddSource(CFRunLoopGetMain(),fnSource,.commonModes)
    CGEvent.tapEnable(tap:fnTap,enable:true)
   } else { errors.append("Allow Accessibility for Fn. Shortcuts will reconnect automatically.") }
  }
  return errors
 }
 private func receive(_ id:UInt32,down:Bool) {
  if down { guard pressed.insert(id).inserted else { return } }
  else { guard pressed.remove(id) != nil else { return } }
  onAction?(id,down)
 }
 private func deliver(_ actions:[FnGesture.Action]) {
  for action in actions {
   switch action {
   case .voiceDown: if voiceUsesFn { onAction?(1,true) }
   case .voiceUp: if voiceUsesFn { onAction?(1,false) }
   case .translate: if translationUsesFn { onAction?(2,true);onAction?(2,false) }
   }
  }
 }
 private func fnChanged(_ down:Bool,at time:TimeInterval = ProcessInfo.processInfo.systemUptime) {
  guard down != fnDown else { return };fnDown = down;holdTask?.cancel()
  if down {
   fnGesture.press(at:time)
   holdTask = Task { [weak self] in
    try? await Task.sleep(for:.seconds(FnGesture.holdDelay))
    guard !Task.isCancelled,let self else { return }
    self.deliver(self.fnGesture.advance(at:ProcessInfo.processInfo.systemUptime))
   }
  } else { deliver(fnGesture.release(at:time)) }
 }
 private func reenableFn() { holdTask?.cancel();holdTask=nil;fnDown=false;deliver(fnGesture.reset()); if let fnTap { CGEvent.tapEnable(tap:fnTap,enable:true) } }
 func unregister() {
  holdTask?.cancel();holdTask=nil;fnDown=false;deliver(fnGesture.reset())
  for id in pressed { onAction?(id,false) }; pressed.removeAll()
  for ref in refs { UnregisterEventHotKey(ref) }; refs.removeAll()
  if let handler { RemoveEventHandler(handler); self.handler = nil }
  if let fnSource { CFRunLoopRemoveSource(CFRunLoopGetMain(),fnSource,.commonModes) }; fnSource = nil
  if let fnTap { CFMachPortInvalidate(fnTap) }; fnTap = nil
 }
}
