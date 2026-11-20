import AppKit
import ApplicationServices

@MainActor final class KeyboardLayoutSwitcher {
    private let monitor = KeyboardMonitor()
    private let converter = TextConverter()
    private struct LastChange {
        let pid: pid_t
        let previousLayout: String
        let newLayout: String
        let replacedText: Bool
    }

    private var lastChange: LastChange?
    private var warmup: Task<Void, Never>?
    private var didWarmUp = false
    private(set) var isRunning = false

    var isRuSwitcherRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.ruswitcher.app").isEmpty
    }

    func start() {
        guard !isRunning, !isRuSwitcherRunning, AXIsProcessTrusted() else { return }

        converter.suspendTap = { [weak monitor] action in
            if let monitor { monitor.withTapSuspended(action) }
            else { action() }
        }
        monitor.onWordBoundary = { [weak self] in
            MainActor.assumeIsolated { self?.correctWord() }
        }
        monitor.onUndoKey = { [weak self] in
            MainActor.assumeIsolated { self?.undo() ?? false }
        }
        isRunning = monitor.start(onAltTap: {}, onAltReconvert: {})
        if isRunning && !didWarmUp {
            warmup = Task { [weak self] in
                await Task.yield()
                guard !Task.isCancelled, let self else { return }
                Dict.warmUp()
                self.didWarmUp = true
            }
        }
    }

    func stop() {
        warmup?.cancel()
        warmup = nil
        if isRunning { monitor.stop() }
        isRunning = false
        reset()
    }

    func reset() {
        monitor.resetBuffersOnClick()
        converter.clearState()
        lastChange = nil
    }

    private func correctWord() {
        guard isRunning, !isRuSwitcherRunning, !AutoSwitchPolicy.secureInputActive,
              let app = NSWorkspace.shared.frontmostApplication,
              !AutoSwitchPolicy.isDeniedApp(app.bundleIdentifier),
              monitor.prevWordBundleID == app.bundleIdentifier,
              !isSecureField(in: app),
              let languages = LayoutSwitcher.currentAndOppositeLanguage()
        else { return }

        let keys = monitor.prevWordKeys
        let boundaryCount = monitor.boundaryCount
        guard boundaryCount > 0, !keys.isEmpty, keys.count <= 32,
              let pair = DynamicKeyMapping.convertKeys(keys) else { return }

        if pair.original == pair.converted {
            if Self.shouldSwitchWithoutReplacement(pair.original, from: languages.current, to: languages.opposite) {
                converter.clearState()
                finishConversion(in: app, replacedText: false)
            }
            return
        }

        guard case .convert(let coreLength) = LayoutDetector.plan(
                  typed: pair.original, converted: pair.converted,
                  canSplit: pair.original.count == keys.count,
                  currentLang: languages.current, otherLang: languages.opposite,
                  capsLock: keys.contains { $0.caps }, suffixConvertible: true
              )
        else { return }

        let suffix = String(pair.original.dropFirst(coreLength))
        if SpotlightAX.isActive() {
            guard suffix.isEmpty,
                  converter.convertSpotlightWord(converted: pair.converted, boundaryCount: boundaryCount)
            else { return }
            finishConversion(in: app)
            return
        }
        let coreKeys = suffix.isEmpty ? keys : Array(keys.prefix(coreLength))
        guard converter.convert(wordKeys: [], prevWordKeys: coreKeys, boundaryCount: boundaryCount,
                                passthroughSuffix: DynamicKeyMapping.punctThroughCurrentPair(suffix),
                                typedSuffix: suffix)
        else { return }

        finishConversion(in: app)
    }

    static func shouldSwitchWithoutReplacement(_ word: String, from source: String, to target: String) -> Bool {
        let source = String(source.prefix(2)), target = String(target.prefix(2))
        let normalized = word.lowercased()
        return source != target && word.count >= 4 && word.allSatisfy(\.isLetter)
            && Dict.isAvailable(source) && Dict.isAvailable(target)
            && !Dict.isValidWord(normalized, lang: source) && Dict.isValidWord(normalized, lang: target)
    }

    private func finishConversion(in app: NSRunningApplication, replacedText: Bool = true) {
        monitor.markConverted()
        let previous = LayoutSwitcher.currentLayoutID()
        LayoutSwitcher.switchToOpposite()
        let selected = LayoutSwitcher.currentLayoutID()
        guard selected != previous else { lastChange = nil; return }
        lastChange = LastChange(pid: app.processIdentifier, previousLayout: previous,
                                newLayout: selected, replacedText: replacedText)
    }

    private func undo() -> Bool {
        guard isRunning, !monitor.keysTypedSinceConversion, let change = lastChange,
              let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier == change.pid,
              !AutoSwitchPolicy.secureInputActive, !isSecureField(in: app),
              LayoutSwitcher.currentLayoutID() == change.newLayout,
              !change.replacedText || converter.reconvert()
        else { return false }

        LayoutSwitcher.switchTo(layoutID: change.previousLayout)
        reset()
        return true
    }

    private func isSecureField(in app: NSRunningApplication) -> Bool {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(axApp, 0.05)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return false }
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(value as! AXUIElement, kAXSubroleAttribute as CFString, &subrole)
        return subrole as? String == kAXSecureTextFieldSubrole
    }
}
