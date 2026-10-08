PROJECT_NAME := OpencodeUsage
APP_NAME := OpenCode Usage
BUNDLE_ID := com.wiscaksono.opencode-usage

VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
ifeq ($(strip $(VERSION)),)
VERSION := 0.0.0
endif

WIDGET_NAME := OpencodeUsageWidget

BUILD_DIR := build
DEBUG_APP_BUNDLE := $(BUILD_DIR)/Debug/$(APP_NAME).app
RELEASE_APP_BUNDLE := $(BUILD_DIR)/Release/$(APP_NAME).app
APPEX_DIR := $(BUNDLE_PATH)/Contents/PlugIns/$(WIDGET_NAME).appex

.PHONY: build release bundle bundle-widget run clean test format logs dmg

build:
	swift build
	@$(MAKE) bundle CONFIG=debug BUNDLE_PATH="$(DEBUG_APP_BUNDLE)" VERSION="$(VERSION)"

release:
	swift build -c release
	@$(MAKE) bundle CONFIG=release BUNDLE_PATH="$(RELEASE_APP_BUNDLE)" VERSION="$(VERSION)"

bundle:
	mkdir -p "$(BUNDLE_PATH)/Contents/MacOS" "$(BUNDLE_PATH)/Contents/Resources"
	cp ".build/$(CONFIG)/$(PROJECT_NAME)" "$(BUNDLE_PATH)/Contents/MacOS/$(APP_NAME)"
	cp Support/Info.plist "$(BUNDLE_PATH)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(BUNDLE_PATH)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" "$(BUNDLE_PATH)/Contents/Info.plist"
	# SwiftPM resource bundle: required at runtime by Bundle.module. Without
	# this the bundled app traps on launch when resolving its resources.
	cp -R ".build/$(CONFIG)/$(PROJECT_NAME)_$(PROJECT_NAME).bundle" "$(BUNDLE_PATH)/Contents/Resources/"
	cp Sources/OpencodeUsage/Resources/AppIcon.icns "$(BUNDLE_PATH)/Contents/Resources/AppIcon.icns"
	@$(MAKE) bundle-widget CONFIG=$(CONFIG) APPEX_DIR="$(APPEX_DIR)" VERSION="$(VERSION)"
	codesign --force --sign - "$(BUNDLE_PATH)"

# SwiftPM has no app-extension product: assemble the widget binary into an
# .appex by hand, stamp it, and sign it with the sandbox entitlements.
bundle-widget:
	mkdir -p "$(APPEX_DIR)/Contents/MacOS"
	cp ".build/$(CONFIG)/$(WIDGET_NAME)" "$(APPEX_DIR)/Contents/MacOS/$(WIDGET_NAME)"
	cp Support/Widget-Info.plist "$(APPEX_DIR)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(APPEX_DIR)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" "$(APPEX_DIR)/Contents/Info.plist"
	codesign --force --sign - --entitlements Support/OpencodeUsageWidget.entitlements "$(APPEX_DIR)"

run: build
	killall "$(APP_NAME)" 2>/dev/null || true
	open "$(DEBUG_APP_BUNDLE)"

clean:
	rm -rf .build $(BUILD_DIR) "$(APP_NAME).dmg"

test:
	swift test

format:
	swiftformat .

logs:
	log stream --predicate 'subsystem == "$(BUNDLE_ID)"' --level info

dmg: release
	@rm -f "$(APP_NAME).dmg"
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(RELEASE_APP_BUNDLE)" \
		-ov -format UDZO \
		"$(APP_NAME).dmg"
	@echo "Created $(APP_NAME).dmg"
