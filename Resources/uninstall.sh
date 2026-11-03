#!/bin/zsh
# Removes Second Display and everything it leaves behind. Usage: run from inside the app bundle.
ID=com.mmacierzanka.seconddisplay
APP="${0:A:h:h:h}"
[[ "$APP" == *.app && "$(defaults read "$APP/Contents/Info" CFBundleIdentifier 2>/dev/null)" == "$ID" ]] || { echo "Not a Second Display bundle: $APP"; exit 1; }
read -q "?Delete $APP and all its data? [y/N] " || { echo; echo Cancelled; exit 0; }
echo
pkill -x SecondDisplay 2>/dev/null
defaults delete "$ID" 2>/dev/null
tccutil reset All "$ID" >/dev/null 2>&1   # camera / microphone permissions
L=~/Library
rm -rf "$L/Preferences/$ID.plist" "$L/Caches/$ID" "$L/HTTPStorages/$ID" "$L/Saved Application State/$ID.savedState" \
       "$L/Application Support/$ID" "$L/Containers/$ID" "$L/WebKit/$ID" "$L/Logs/$ID"
killall cfprefsd 2>/dev/null
echo "Removed. Deleting $APP"
rm -rf "$APP"
