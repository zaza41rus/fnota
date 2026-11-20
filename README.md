# fnota

fnota is a free, open-source macOS menu bar app for **automatic keyboard layout correction**, on-device dictation, and browser translation. It can also temporarily keep your Mac awake.

**Requires Apple Silicon (M1 or later) and macOS 27 or later.** [Download the preview](https://github.com/zaza41rus/fnota/releases) · [Build from source](BUILD.md) · [Changelog](CHANGELOG.md)

## Automatic keyboard layout correction

fnota can correct words typed in the wrong keyboard layout and switch to the intended layout. Correction runs locally on your Mac.

1. In macOS Keyboard settings, enable input sources for exactly two languages.
2. In fnota, go to **Settings → Keyboard layout** and turn on **Automatically switch keyboard layouts**. The panel shows the active pair. The feature is off by default.
3. Type normally. After **Space**, fnota can correct a recognized word and switch to the intended layout. Press **Esc** immediately to undo.

Grant Accessibility access. If keyboard monitoring is unavailable, check Input Monitoring and reopen fnota. The switcher skips secure input and certain apps. Names, short words, custom layouts, and unusual text fields may behave differently. Coverage across all apps and language pairs remains unverified.

You can also find these instructions in **Settings → About fnota** in the current preview.

## Other features

| Feature | How to use it | Permissions |
| --- | --- | --- |
| Dictation | Hold **fn** to record and release it to transcribe and insert text. The result is also copied to the clipboard. | Microphone and Accessibility |
| Browser translation | Double-press **fn** in Safari or Chrome to translate a selection or the page. Repeat to restore the original. PDF and text in images are unsupported. | Accessibility, browser Automation, and Allow JavaScript from Apple Events |
| Keep Awake | Turn it on from the menu bar. A pink dot next to **fn** shows that it is active. The closed-lid mode temporarily prevents normal sleep. | Administrator approval for the closed-lid helper |

Install compatible models in fnota before using dictation or translation. Available languages depend on the models you install. Turn off Keep Awake and check that the Mac has gone to sleep before carrying it. If you installed the helper, remove it from **Settings → About fnota → Remove closed-lid helper** before uninstalling fnota. [How the helper works](UniversalMac/docs/CLOSED_LID.md)

## Privacy and limitations

- Dictation, translation, and layout correction run on your Mac. Model catalogs and downloads use the internet and send ordinary request data to third-party hosts.
- Dictation uses a temporary audio file that fnota removes on normal completion. Transcribed text may remain in the system clipboard or in clipboard managers.
- Layout correction uses global keyboard events. You can disable the feature in fnota or revoke its permissions in **System Settings → Privacy & Security**.
- Models can use substantial disk space and memory. Review important text after dictation, translation, or layout correction.

## Installation and source code

Download the ZIP from [Releases](https://github.com/zaza41rus/fnota/releases), unzip it, and move `fnota.app` to **Applications**. Each preview includes installation instructions and a SHA-256 checksum. The app is ad hoc signed and has no Apple notarization. Gatekeeper may block it on another Mac.

To get the source, choose **Code → Download ZIP** or run `git clone https://github.com/zaza41rus/fnota.git`. Use **Fork** to start your own version. For bug reports, include your macOS version, the affected app, and steps to reproduce. Use sample text and remove personal data from logs.

fnota's original code is available under the [MIT License](LICENSE). You can use, modify, and redistribute it while preserving the copyright and license notices. Third-party code, word lists, native libraries, and downloadable models retain their own terms. [Third-party notices](UniversalMac/Resources/THIRD_PARTY.md)

The software is provided as is, without warranty. The MIT License limits liability to the extent permitted by applicable law.
