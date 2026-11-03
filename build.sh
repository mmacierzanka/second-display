#!/bin/zsh
set -e
cd "$(dirname "$0")"
A="SecondDisplay.app"
rm -rf "$A"; mkdir -p "$A/Contents/MacOS"
swiftc -O Sources/main.swift -o "$A/Contents/MacOS/SecondDisplay"
cat > "$A/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>pl</string></array>
<key>CFBundleExecutable</key><string>SecondDisplay</string>
<key>CFBundleIdentifier</key><string>local.seconddisplay</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>Second Display</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSCameraUsageDescription</key><string>Shows video from the capture device.</string>
<key>NSMicrophoneUsageDescription</key><string>Plays audio from the selected input.</string>
</dict></plist>
P
for L in en pl; do mkdir -p "$A/Contents/Resources/$L.lproj"; cp Resources/$L.lproj/*.strings "$A/Contents/Resources/$L.lproj/"; done
cp Resources/AppIcon.icns "$A/Contents/Resources/"
codesign --force --sign - "$A"
