# Second Display

Natywna aplikacja macOS, która pokazuje w oknie obraz z urządzenia przechwytującego (capture card, kamerka) i odtwarza dźwięk z wybranego wejścia — jako "drugi monitor".

## Wymagania
macOS 26+, Xcode (Command Line Tools).

## Budowanie i uruchamianie
```
make          # buduje build/SecondDisplay.app
make run      # buduje i uruchamia
make check    # lint: typecheck, plisty, tłumaczenia, podpis
make install  # kopiuje do ~/Applications
make help     # lista poleceń
```
Podpis jest ad-hoc (działa na tym Macu). Do dystrybucji: `make SIGN_ID="Developer ID Application: ..."` (potrzebna jeszcze notaryzacja).

## Użycie
Menu u góry ekranu: **Obraz** (kamera, format), **Dźwięk** (źródło lub wyłączony), **Opcje** (blokada usypiania, pełny ekran przy starcie, na wierzchu, wyciszenie ⇧⌘M, skalowanie), **Okno** (kafelkowanie, pełny ekran ⌃⌘F).

## Struktura
- `Sources/` – aplikacja (AppKit + AVFoundation): `App` (stan, okno), `Capture` (urządzenia, formaty), `Menu`, `Power`, `Preferences`, `main` (start)
- `Config/` – `Info.plist`, entitlements (kamera, mikrofon)
- `Resources/` – ikona (`AppIcon.icon`, Icon Composer), tłumaczenia en/pl, `uninstall.sh`
- `scripts/check-strings.sh` – spójność tłumaczeń

## Ustawienia i odinstalowanie
Ustawienia: `~/Library/Preferences/com.mmacierzanka.seconddisplay.plist`.
Pełne usunięcie aplikacji i śladów: `make uninstall` albo `SecondDisplay.app/Contents/Resources/uninstall.sh`.
