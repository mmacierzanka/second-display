#!/bin/zsh
# Removes Second Display and everything it leaves behind. Usage: run from inside the app bundle.
ID=com.mmacierzanka.second-display
APP="${0:A:h:h:h}"
[[ "$APP" == *.app && "$(defaults read "$APP/Contents/Info" CFBundleIdentifier 2>/dev/null)" == "$ID" ]] || { echo "Not a Second Display bundle: $APP"; exit 1; }
read -q "?Delete $APP and all its data? [y/N] " || { echo; echo Cancelled; exit 0; }
echo
pkill -x "Second Display" 2>/dev/null
launchctl bootout "gui/$(id -u)/$ID.autostart" 2>/dev/null   # launch-on-connect agent
rm -f ~/Library/LaunchAgents/$ID.autostart.plist
defaults delete "$ID" 2>/dev/null
tccutil reset All "$ID" >/dev/null 2>&1   # camera / microphone permissions
L=~/Library
rm -rf "$L/Preferences/$ID.plist" "$L/Caches/$ID" "$L/Saved Application State/$ID.savedState"
killall cfprefsd 2>/dev/null
echo "Removed. Deleting $APP"
rm -rf "$APP"
