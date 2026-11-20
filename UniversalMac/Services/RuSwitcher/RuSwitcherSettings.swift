/// Maps the imported engine's settings onto fnota's Russian/English automatic mode.
struct RuSwitcherSettings: Sendable {
    static let shared = Self()

    let layout1ID = ""
    let layout2ID = ""
    let wordEndOnSpace = true
    let wordEndOnEnter = false
    let wordEndOnTab = false
    let wordEndPipelineActive = true
    let remoteDesktopMode = false
    let keySound = false
    let debugLogEnabled = false
    let convertByText = false
    let smartConversion = true
    let deniedApps = AutoSwitchPolicy.defaultDeniedApps
    let deniedWordsSet: Set<String> = []
    let alwaysConvertWordsSet: Set<String> = []
    let triggerKey = ""

    func hotkey(_ slot: HotkeySlot) -> HotkeySetting {
        HotkeySetting(key: "", side: .any, doubleTap: false)
    }
}
