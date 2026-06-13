.PHONY: build install clean run dmg dmg-simple

APP_NAME = RingGlow
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

build:
	@./build.sh

# Build + install hooks + launch (recommended for first install and daily use)
install: build
	@open $(APP_BUNDLE)
	@echo ""
	@echo "==> RingGlow 已启动！"
	@echo "    请重启 Claude Code 以使 Hook 生效"

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
