APP      := build/SecondDisplay.app
SRC      := $(wildcard Sources/*.swift)
RES      := $(shell find Resources -type f)
# "-" = ad-hoc; set SIGN_ID to a Developer ID identity for distribution
SIGN_ID  ?= -
BUILDNUM := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)

.PHONY: build run clean install uninstall check help
build: $(APP) ## Build build/SecondDisplay.app

$(APP): Makefile $(SRC) $(RES) Config/Info.plist Config/SecondDisplay.entitlements
	rm -rf $(APP) && mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	swiftc -O $(SRC) -o $(APP)/Contents/MacOS/SecondDisplay
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

help: ## List targets
	@grep -E '^[a-z]+:.*##' Makefile | sed 's/:.*##/ -/'
