#!/bin/zsh
# Fails if en/pl Localizable.strings differ in keys or code uses a key missing from them.
cd "$(dirname "$0")/.."
keys() { grep -o '^"[^"]*"' "Resources/$1.lproj/Localizable.strings" | sort; }
used=$(grep -oh 'NSLocalizedString("[^"]*"' Sources/*.swift | sed 's/NSLocalizedString(//' | sort -u)
# keys passed through a variable (e.g. the Fit/Fill/Stretch loop) are not caught by the grep above; list them in the pl/en parity check only
fail=0
diff <(keys en) <(keys pl) >/dev/null || { echo "en and pl keys differ:"; diff <(keys en) <(keys pl); fail=1; }
missing=$(comm -23 <(echo "$used") <(keys en))
[[ -z "$missing" ]] || { echo "Used but missing in en:"; echo "$missing"; fail=1; }
exit $fail
