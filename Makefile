.PHONY: build clean run dmg dmg-simple

APP_NAME = RingGlow
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

build:
	@./build.sh

clean:
	@rm -rf $(BUILD_DIR)

run: build
	@open $(APP_BUNDLE)

# Professional DMG with drag-to-install interface, background, and icon layout
dmg: build
	@./scripts/create-dmg.sh

# Simple DMG without customization (fallback)
dmg-simple: build
	@echo "==> Creating simple DMG..."
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(APP_BUNDLE) \
		-ov -format UDZO \
		$(BUILD_DIR)/$(APP_NAME).dmg
	@echo "==> DMG created: $(BUILD_DIR)/$(APP_NAME).dmg"
