# Second Display – brief

## Goal
A native macOS app that shows video from a capture device (camera / capture card) in a window and plays audio from a chosen input. It is meant to work as a "second monitor".

## Requirements
- Menus live in the app's main menu bar at the top of the screen (not a status-bar icon): video source, audio source, and an option to turn audio off.
- Optional display-sleep prevention while the app is active. On by default, choice is remembered.
- Optional start in full screen. On by default, choice is remembered.
- Localization: English and Polish (`Resources/{en,pl}.lproj`), following the system language.
- Extras: per-device format (resolution/FPS), scaling modes (fit/fill/stretch), always on top, mute (⇧⌘M), Window menu (system tiling, full screen ⌃⌘F), automatic resume when a device is unplugged/replugged.
- Out of scope (for now): launch at login, recording, screenshots, volume slider.

## Structure
- `Sources/` – app code (AppKit + AVFoundation, one `AVCaptureSession`, audio via `AVCaptureAudioPreviewOutput`). The `App` class is split into extensions:
  `main.swift` (entry point), `App.swift` (state, window, lifecycle), `Capture.swift` (devices, formats, hot-plug), `Menu.swift` (menus and actions), `Power.swift` (sleep prevention), `Preferences.swift` (UserDefaults-backed settings).
- `Config/Info.plist`, `Config/SecondDisplay.entitlements` – version, permissions (camera, microphone; hardened runtime).
- `Resources/` – `AppIcon.icon` (Icon Composer, Liquid Glass; compiled by `actool`), `{en,pl}.lproj` (`Localizable.strings`, `InfoPlist.strings`), `uninstall.sh` (copied into the bundle; removes the app, preferences, caches, TCC permissions). Bundle ID: `com.mmacierzanka.seconddisplay`.
- `scripts/check-strings.sh` – en/pl translation consistency.
- `Makefile` – `make` (builds `build/SecondDisplay.app`), `run`, `check`, `install`, `uninstall`, `clean`, `help`. `SIGN_ID` defaults to ad-hoc (`-`).

## Conventions
- Settings live in `UserDefaults` (keys: `video`, `audio`, `keepAwake`, `startFull`, `onTop`, `gravity`, `format.<id>`).
- Add new strings through `NSLocalizedString` and to both `Localizable.strings` files.
- Run `make check` before committing. Version is in `Config/Info.plist`; build number = commit count.
- Commits: small, one per feature, with a `Co-Authored-By` line.
