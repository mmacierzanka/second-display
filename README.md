# Second Display

A native macOS app that shows video from a capture device (capture card, camera) in a window and plays audio from a chosen input — a "second monitor".

## Requirements
macOS 26+, Xcode (Command Line Tools).

## Build and run
```
make          # builds build/SecondDisplay.app
make run      # build and launch
make check    # lint: typecheck, plists, translations, signature
make install  # copy to ~/Applications
make help     # list targets
```
The app is signed ad-hoc (works on this Mac). For distribution: `make SIGN_ID="Developer ID Application: ..."` (notarization is still required).

## Usage
Menus at the top of the screen: **Video** (device, format), **Audio** (source or off), **Options** (prevent display sleep, start in full screen, always on top, mute ⇧⌘M, scaling), **Window** (tiling, full screen ⌃⌘F).

## Layout
- `Sources/` – the app (AppKit + AVFoundation): `App` (state, window), `Capture` (devices, formats), `Menu`, `Power`, `Preferences`, `main` (entry point)
- `Config/` – `Info.plist`, entitlements (camera, microphone)
- `Resources/` – icon (`AppIcon.icon`, Icon Composer), en/pl translations, `uninstall.sh`
- `scripts/check-strings.sh` – translation consistency

## Settings and uninstall
Settings: `~/Library/Preferences/com.mmacierzanka.seconddisplay.plist`.
To remove the app and all its traces: `make uninstall` or `SecondDisplay.app/Contents/Resources/uninstall.sh`.
