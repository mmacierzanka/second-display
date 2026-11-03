APP      := build/SecondDisplay.app
SRC      := $(wildcard Sources/*.swift)
RES      := $(shell find Resources -type f)
# "-" = ad-hoc; set SIGN_ID to a Developer ID identity for distribution
SIGN_ID  ?= -
BUILDNUM := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)

VERSION  := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Config/Info.plist)
DMG      := build/SecondDisplay-$(VERSION).dmg
VOLNAME  ?= Second Display

.PHONY: build run clean install uninstall check dmg help
build: $(APP) ## Build build/SecondDisplay.app

$(APP): Makefile $(SRC) $(RES) Config/Info.plist Config/SecondDisplay.entitlements
	rm -rf $(APP) && mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	swiftc -O -target arm64-apple-macos26.0 $(SRC) -o $(APP)/Contents/MacOS/SecondDisplay-arm64
	swiftc -O -target x86_64-apple-macos26.0 $(SRC) -o $(APP)/Contents/MacOS/SecondDisplay-x86_64
	lipo -create $(APP)/Contents/MacOS/SecondDisplay-* -output $(APP)/Contents/MacOS/SecondDisplay
	rm $(APP)/Contents/MacOS/SecondDisplay-*
	cp Config/Info.plist $(APP)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILDNUM)" $(APP)/Contents/Info.plist
	cp -R Resources/en.lproj Resources/pl.lproj Resources/uninstall.sh $(APP)/Contents/Resources/
	xcrun actool Resources/AppIcon.icon --compile $(APP)/Contents/Resources --platform macosx \
		--minimum-deployment-target 26.0 --app-icon AppIcon --output-partial-info-plist /dev/null >/dev/null
	codesign --force --options runtime --entitlements Config/SecondDisplay.entitlements --sign "$(SIGN_ID)" $(APP)

run: build ## Build and launch
	open $(APP)

clean: ## Remove build output
	rm -rf build

install: build ## Copy to ~/Applications
	mkdir -p ~/Applications && rm -rf ~/Applications/SecondDisplay.app && cp -R $(APP) ~/Applications/

uninstall: ## Remove the installed app and all its leftovers
	~/Applications/SecondDisplay.app/Contents/Resources/uninstall.sh

check: build ## Lint sources, plists, strings and the built bundle
	swiftc -typecheck $(SRC)
	plutil -lint Config/Info.plist Config/SecondDisplay.entitlements Resources/*.lproj/*.strings
	scripts/check-strings.sh
	codesign --verify --strict $(APP)

DMGBUILD := build/venv/bin/dmgbuild

$(DMGBUILD):
	python3 -m venv build/venv && build/venv/bin/pip install -q dmgbuild

dmg: build $(DMGBUILD) ## Build a distributable disk image (not notarized)
	rm -f $(DMG)
	$(DMGBUILD) -s Config/dmg/settings.py -D app=$(APP) "$(VOLNAME)" $(DMG)
	hdiutil verify $(DMG) | tail -1

help: ## List targets
	@grep -E '^[a-z]+:.*##' Makefile | sed 's/:.*##/ -/'
