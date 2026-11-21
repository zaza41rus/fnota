import AppKit
import QuartzCore

@MainActor final class Overlay {
 var onStatus:((String)->Void)?
 private var panel:NSPanel?
 private var positionTimer:Timer?

 func show(_ text:String,persistent:Bool = false) { onStatus?(text) }
 func hide() {}

 /// The wave follows the original dictation window without receiving input.
 func showRecording(frame: @escaping @MainActor () -> NSRect?) {
  hideRecording()
  let originPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
  guard let target = frame(),let rect = waveFrame(in:target) else { return }
  let wave = RecordingWaveView(frame:NSRect(origin:.zero,size:rect.size))
  panel = makePanel(frame:rect,view:wave)
  let timer = Timer(timeInterval:0.15,repeats:true) { [weak self] _ in
   MainActor.assumeIsolated {
    guard let self,let panel = self.panel else { return }
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == originPID,
          let current = frame(),let rect = self.waveFrame(in:current) else {
     self.hideRecording()
     return
    }
    if rect != panel.frame { panel.setFrame(rect,display:true) }
   }
  }
  positionTimer = timer
  RunLoop.main.add(timer,forMode:.common)
 }

 func updateRecordingLevel(_ level:Float) {
  (panel?.contentView as? RecordingWaveView)?.update(level:level)
 }

 private func waveFrame(in window:NSRect)->NSRect? {
  guard window.width >= 64,window.height >= 64 else { return nil }
  let width = min(window.width * 0.92,1000)
  let height = min(window.height,92)
  return NSRect(x:window.midX-width/2,y:window.minY,width:width,height:height)
 }

 private func makePanel(frame:NSRect,view:NSView)->NSPanel {
  let panel = NSPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],
                      backing:.buffered,defer:false)
  panel.isReleasedWhenClosed = false
  panel.isOpaque = false
  panel.backgroundColor = .clear
  panel.hasShadow = false
  panel.hidesOnDeactivate = false
  panel.ignoresMouseEvents = true
  panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
  panel.level = .floating
  panel.contentView = view
  panel.orderFrontRegardless()
  return panel
 }

 func hideRecording() {
  positionTimer?.invalidate()
  positionTimer = nil
  panel?.orderOut(nil)
  panel?.close()
  panel = nil
 }
}

private enum RecordingColors {
 static let palette = [
  NSColor(srgbRed:0.29,green:0.67,blue:1,alpha:1).cgColor,
  NSColor(srgbRed:0.58,green:0.34,blue:1,alpha:1).cgColor,
  NSColor(srgbRed:0.98,green:0.34,blue:0.74,alpha:1).cgColor,
  NSColor(srgbRed:1,green:0.53,blue:0.37,alpha:1).cgColor,
  NSColor(srgbRed:0.27,green:0.89,blue:0.87,alpha:1).cgColor
 ]

 @MainActor static func animate(_ gradient:CAGradientLayer,colors:[CGColor]) {
  guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
  let motion = CAKeyframeAnimation(keyPath:"colors")
  motion.values = (0...colors.count).map { phase in
   (0...colors.count).map { colors[($0 + phase) % colors.count] }
  }
  motion.duration = 4.2
  motion.repeatCount = .infinity
  gradient.add(motion,forKey:"dictation-color-wave")
 }
}

@MainActor private final class RecordingWaveView:NSView {
 private let gradient = CAGradientLayer()
 private let taper = CAGradientLayer()
 private let curves = CALayer()
 // Overlapping masks approximate a soft falloff without a high-opacity core.
 private let haze:[(width:CGFloat,alpha:CGFloat)] = [
  (54,0.035),(46,0.045),(38,0.065),(30,0.085),
  (23,0.105),(17,0.125),(11,0.13),(6,0.10)
 ]
 private lazy var strokes = haze.map { _ in CAShapeLayer() }
 private let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
 private var intensity:CGFloat = 0
 private var phase:CGFloat = 0

 override init(frame:NSRect) {
  super.init(frame:frame)
  wantsLayer = true
  let palette = RecordingColors.palette
  gradient.colors = palette + [palette[0]]
  gradient.startPoint = CGPoint(x:0,y:0.5)
  gradient.endPoint = CGPoint(x:1,y:0.5)
  taper.colors = [NSColor.clear.cgColor,NSColor.white.cgColor,
                  NSColor.white.cgColor,NSColor.clear.cgColor]
  taper.locations = [0,0.2,0.8,1]
  taper.startPoint = CGPoint(x:0,y:0.5)
  taper.endPoint = CGPoint(x:1,y:0.5)
  layer?.mask = taper
  for (index,stroke) in strokes.enumerated() {
   stroke.fillColor = nil
   stroke.strokeColor = NSColor.white.withAlphaComponent(haze[index].alpha).cgColor
   stroke.lineWidth = haze[index].width
   stroke.lineCap = .round
   stroke.shadowColor = NSColor.white.cgColor
   stroke.shadowOpacity = 0.65
   stroke.shadowRadius = 9
   stroke.shadowOffset = .zero
   curves.addSublayer(stroke)
  }
  gradient.mask = curves
  layer?.addSublayer(gradient)
  RecordingColors.animate(gradient,colors:palette)
 }

 required init?(coder:NSCoder) { nil }

 func update(level:Float) {
  guard !reducedMotion else { return }
  let target = CGFloat(max(0,min(1,level)))
  let rise = max(0,target-intensity)
  intensity += (target-intensity) * (target > intensity ? 0.88 : 0.49)
  phase += 0.035 + intensity*0.14 + rise*0.42
  updatePaths()
 }

 override func layout() {
  super.layout()
  CATransaction.begin()
  CATransaction.setDisableActions(true)
  gradient.frame = bounds
  taper.frame = bounds
  curves.frame = bounds
  for stroke in strokes { stroke.frame = bounds }
  updatePaths()
  CATransaction.commit()
 }

 private func updatePaths() {
  guard bounds.width > 0 else { return }
  CATransaction.begin()
  CATransaction.setDisableActions(true)
  let path = CGMutablePath()
  for step in 0...64 {
   let x = CGFloat(step)/64
   let envelope = sin(x * .pi)
   let harmonic = sin(x * .pi * 5 - phase)
   let amplitude = 2 + intensity*22
   let y = 12 + envelope * (12 + intensity*22 + harmonic*amplitude)
   let point = CGPoint(x:x*bounds.width,y:y)
   if step == 0 { path.move(to:point) }
   else { path.addLine(to:point) }
  }
  gradient.opacity = Float(0.58 + 0.42*intensity)
  for stroke in strokes { stroke.path = path }
  CATransaction.commit()
 }
}
