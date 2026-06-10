.PHONY: build clean run dmg

APP_NAME = RingGlow
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

build:
	@./build.sh

clean:
	@rm -rf $(BUILD_DIR)

run: build
	@open $(APP_BUNDLE)

dmg: build
	@echo "==> Creating DMG installer..."
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(APP_BUNDLE) \
		-ov -format UDZO \
		$(BUILD_DIR)/$(APP_NAME).dmg
	@echo "==> DMG created: $(BUILD_DIR)/$(APP_NAME).dmg"
