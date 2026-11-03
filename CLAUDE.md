# Second Display – brief

## Cel
Aplikacja natywna na macOS, która wyświetla w oknie obraz z urządzenia przechwytującego (kamerki / capture card) oraz odtwarza dźwięk z wybranego źródła (wejścia) dźwięku. Ma służyć jako "drugi monitor".

## Wymagania
- Menu (główne menu aplikacji u góry ekranu, nie ikona statusowa po prawej): wybór źródła obrazu, wybór źródła dźwięku oraz opcja wyłączenia dźwięku.
- Opcjonalna (włączana/wyłączana) blokada usypiania ekranu w trakcie aktywności aplikacji. Domyślnie włączona, wybór zapamiętywany.
- Opcjonalne uruchamianie na pełnym ekranie. Domyślnie włączone, wybór zapamiętywany.
- Lokalizacja: angielski i polski (`Resources/{en,pl}.lproj`), język wg ustawień systemu.
- Dodatki: wybór formatu (rozdzielczość/FPS) per urządzenie, tryby skalowania (dopasuj/wypełnij/rozciągnij), okno zawsze na wierzchu, wyciszenie (⇧⌘M), menu Okno (kafelkowanie systemowe, pełny ekran ⌃⌘F), automatyczne wznawianie po odpięciu/wpięciu urządzenia.
- Poza zakresem (na razie): start przy logowaniu, nagrywanie, zrzuty ekranu, suwak głośności.

## Struktura
- `Sources/main.swift` – cała aplikacja (AppKit + AVFoundation, jedna sesja `AVCaptureSession`, dźwięk przez `AVCaptureAudioPreviewOutput`).
- `Config/Info.plist`, `Config/SecondDisplay.entitlements` – wersja, uprawnienia (kamera, mikrofon; hardened runtime).
- `Resources/` – `AppIcon.icon` (Icon Composer, Liquid Glass; kompilowana przez `actool`), `{en,pl}.lproj` (`Localizable.strings`, `InfoPlist.strings`), `uninstall.sh` (kopiowany do bundla; usuwa aplikację, preferencje, cache, uprawnienia TCC). Bundle ID: `com.mmacierzanka.seconddisplay`.
- `scripts/check-strings.sh` – spójność tłumaczeń en/pl.
- `Makefile` – `make` (build do `build/SecondDisplay.app`), `run`, `check`, `install`, `uninstall`, `clean`, `help`. `SIGN_ID` domyślnie ad-hoc (`-`).

## Konwencje
- Ustawienia w `UserDefaults` (klucze: `video`, `audio`, `keepAwake`, `startFull`, `onTop`, `gravity`, `format.<id>`).
- Nowe napisy dodawaj przez `NSLocalizedString` oraz do obu plików `Localizable.strings`.
- Przed commitem: `make check`. Wersja w `Config/Info.plist`, numer buildu = liczba commitów.
- Commity: małe, osobne na funkcję, z linią `Co-Authored-By`.
