NAME     := Second Display
APP      := build/$(NAME).app
# GNU make cannot use paths with spaces as targets, so builds are tracked by a stamp file
STAMP    := build/.app-built
SRC      := $(wildcard Sources/*.swift)
RES      := $(shell find Resources -type f)
ENTITLEMENTS := Config/second-display.entitlements
# "-" = ad-hoc; set SIGN_ID to a Developer ID identity for distribution
SIGN_ID  ?= -
BUILDNUM := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)

VERSION  := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Config/Info.plist)
DMG      := build/second-display-$(VERSION).dmg
VOLNAME  ?= $(NAME)

.PHONY: build run clean install install-user uninstall check dmg help
build: $(STAMP) ## Build build/Second Display.app

$(STAMP): Makefile $(SRC) $(RES) Config/Info.plist $(ENTITLEMENTS)
	rm -rf "$(APP)" && mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	swiftc -O -target arm64-apple-macos26.0 $(SRC) -o build/arm64
	swiftc -O -target x86_64-apple-macos26.0 $(SRC) -o build/x86_64
	lipo -create build/arm64 build/x86_64 -output "$(APP)/Contents/MacOS/$(NAME)"
	rm build/arm64 build/x86_64
	cp Config/Info.plist "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILDNUM)" "$(APP)/Contents/Info.plist"
	cp -R Resources/en.lproj Resources/pl.lproj Resources/uninstall.sh "$(APP)/Contents/Resources/"
	xcrun actool Resources/AppIcon.icon --compile "$(APP)/Contents/Resources" --platform macosx \
		--minimum-deployment-target 26.0 --app-icon AppIcon --output-partial-info-plist /dev/null >/dev/null
	codesign --force --options runtime --entitlements $(ENTITLEMENTS) --sign "$(SIGN_ID)" "$(APP)"
	touch $(STAMP)

run: build ## Build and launch
	open "$(APP)"

clean: ## Remove build output
	rm -rf build

install: build ## Copy to /Applications
	rm -rf "/Applications/$(NAME).app" && cp -R "$(APP)" /Applications/

install-user: build ## Copy to ~/Applications
	mkdir -p ~/Applications && rm -rf "$$HOME/Applications/$(NAME).app" && cp -R "$(APP)" ~/Applications/

uninstall: ## Remove the installed app (from /Applications or ~/Applications) and all its leftovers
	@for d in /Applications "$$HOME/Applications"; do \
		if [ -d "$$d/$(NAME).app" ]; then "$$d/$(NAME).app/Contents/Resources/uninstall.sh"; exit; fi; \
	done; echo "$(NAME).app is not installed"

check: build ## Lint sources, plists, strings and the built bundle
	swiftc -typecheck $(SRC)
	plutil -lint Config/Info.plist $(ENTITLEMENTS) Resources/*.lproj/*.strings
	scripts/check-strings.sh
	codesign --verify --strict "$(APP)"

DMGBUILD := build/venv/bin/dmgbuild

$(DMGBUILD):
	python3 -m venv build/venv && build/venv/bin/pip install -q dmgbuild

dmg: build $(DMGBUILD) ## Build a distributable disk image (not notarized)
	rm -f $(DMG)
	$(DMGBUILD) -s Config/dmg/settings.py -D app="$(APP)" "$(VOLNAME)" $(DMG)
	hdiutil verify $(DMG) | tail -1

help: ## List targets
	@grep -E '^[a-z-]+:.*##' Makefile | sed 's/:.*##/ -/'
