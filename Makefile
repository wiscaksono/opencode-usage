PROJECT_NAME := OpencodeUsage
APP_NAME := OpenCode Usage
BUNDLE_ID := com.wiscaksono.opencode-usage

VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
ifeq ($(strip $(VERSION)),)
VERSION := 0.0.0
endif

BUILD_DIR := build
DEBUG_APP_BUNDLE := $(BUILD_DIR)/Debug/$(APP_NAME).app
RELEASE_APP_BUNDLE := $(BUILD_DIR)/Release/$(APP_NAME).app

.PHONY: build release bundle run clean test format logs dmg

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
	rm -rf "$(BUNDLE_PATH)/Contents/Resources/$(PROJECT_NAME)_$(PROJECT_NAME).bundle"
	cp -R ".build/$(CONFIG)/$(PROJECT_NAME)_$(PROJECT_NAME).bundle" "$(BUNDLE_PATH)/Contents/Resources/"
	codesign --force --sign - "$(BUNDLE_PATH)"

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
