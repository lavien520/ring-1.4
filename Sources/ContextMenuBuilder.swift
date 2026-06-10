import Cocoa

enum ContextMenuBuilder {
    static func build(onSettings: @escaping () -> Void, onRotate: @escaping () -> Void, onSpin: @escaping () -> Void, onGlow: @escaping () -> Void, onClose: @escaping () -> Void) -> NSMenu {
        let menu = NSMenu()
        let handler = Handler(onSettings: onSettings, onRotate: onRotate, onSpin: onSpin, onGlow: onGlow, onClose: onClose)

        // Keep handler alive as long as the menu exists
        objc_setAssociatedObject(menu, "handler", handler, .OBJC_ASSOCIATION_RETAIN)

        let settingsItem = NSMenuItem(title: "圆环大小", action: #selector(Handler.settingsClicked), keyEquivalent: "")
        settingsItem.target = handler

        let rotateItem = NSMenuItem(title: "旋转", action: #selector(Handler.rotateClicked), keyEquivalent: "")
        rotateItem.target = handler

        let spinItem = NSMenuItem(title: "转圈", action: #selector(Handler.spinClicked), keyEquivalent: "")
        spinItem.target = handler

        let glowItem = NSMenuItem(title: "发光强度", action: #selector(Handler.glowClicked), keyEquivalent: "")
        glowItem.target = handler

        let closeItem = NSMenuItem(title: "关闭", action: #selector(Handler.closeClicked), keyEquivalent: "")
        closeItem.target = handler

        menu.addItem(settingsItem)
        menu.addItem(rotateItem)
        menu.addItem(spinItem)
        menu.addItem(glowItem)
        menu.addItem(closeItem)

        return menu
    }
}

// MARK: - Handler (menu action receiver)

private final class Handler: NSObject {
    let onSettings: () -> Void
    let onRotate: () -> Void
    let onSpin: () -> Void
    let onGlow: () -> Void
    let onClose: () -> Void

    init(onSettings: @escaping () -> Void, onRotate: @escaping () -> Void, onSpin: @escaping () -> Void, onGlow: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onSettings = onSettings
        self.onRotate = onRotate
        self.onSpin = onSpin
        self.onGlow = onGlow
        self.onClose = onClose
    }

    @objc func settingsClicked() {
        onSettings()
    }

    @objc func rotateClicked() {
        onRotate()
    }

    @objc func spinClicked() {
        onSpin()
    }

    @objc func glowClicked() {
        onGlow()
    }

    @objc func closeClicked() {
        onClose()
    }
}
