import Cocoa

enum ContextMenuBuilder {
    static func build(
        currentAppearance: AppearanceMode,
        onSettings: @escaping () -> Void,
        onRotate: @escaping () -> Void,
        onSpin: @escaping () -> Void,
        onGlow: @escaping () -> Void,
        onMemory: @escaping () -> Void,
        onPulse: @escaping () -> Void,
        onExplode: @escaping () -> Void,
        onAppearance: @escaping (AppearanceMode) -> Void,
        onClose: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        let handler = Handler(
            currentAppearance: currentAppearance,
            onSettings: onSettings,
            onRotate: onRotate,
            onSpin: onSpin,
            onGlow: onGlow,
            onMemory: onMemory,
            onPulse: onPulse,
            onExplode: onExplode,
            onAppearance: onAppearance,
            onClose: onClose
        )

        // Keep handler alive as long as the menu exists
        objc_setAssociatedObject(menu, "handler", handler, .OBJC_ASSOCIATION_RETAIN)

        let settingsItem = NSMenuItem(title: "圆环大小", action: #selector(Handler.settingsClicked), keyEquivalent: "")
        settingsItem.target = handler

        // Conditional items based on appearance mode
        let actionItem1: NSMenuItem
        let actionItem2: NSMenuItem
        if currentAppearance == .particleSphere {
            let pulseItem = NSMenuItem(title: "脉冲", action: #selector(Handler.pulseClicked), keyEquivalent: "")
            pulseItem.target = handler
            actionItem1 = pulseItem

            let explodeItem = NSMenuItem(title: "爆炸", action: #selector(Handler.explodeClicked), keyEquivalent: "")
            explodeItem.target = handler
            actionItem2 = explodeItem
        } else {
            let rotateItem = NSMenuItem(title: "旋转", action: #selector(Handler.rotateClicked), keyEquivalent: "")
            rotateItem.target = handler
            actionItem1 = rotateItem

            let spinItem = NSMenuItem(title: "转圈", action: #selector(Handler.spinClicked), keyEquivalent: "")
            spinItem.target = handler
            actionItem2 = spinItem
        }

        let glowItem = NSMenuItem(title: "发光强度", action: #selector(Handler.glowClicked), keyEquivalent: "")
        glowItem.target = handler

        let memoryItem = NSMenuItem(title: "内存使用情况", action: #selector(Handler.memoryClicked), keyEquivalent: "")
        memoryItem.target = handler

        // Appearance submenu
        let appearanceItem = NSMenuItem(title: "外观", action: nil, keyEquivalent: "")
        let appearanceSubmenu = NSMenu()

        let ringItem = NSMenuItem(title: "圆环", action: #selector(Handler.appearanceRingClicked), keyEquivalent: "")
        ringItem.target = handler
        if currentAppearance == .ring { ringItem.state = .on }

        let sphereItem = NSMenuItem(title: "粒子球", action: #selector(Handler.appearanceSphereClicked), keyEquivalent: "")
        sphereItem.target = handler
        if currentAppearance == .particleSphere { sphereItem.state = .on }

        appearanceSubmenu.addItem(ringItem)
        appearanceSubmenu.addItem(sphereItem)
        appearanceItem.submenu = appearanceSubmenu

        let closeItem = NSMenuItem(title: "关闭", action: #selector(Handler.closeClicked), keyEquivalent: "")
        closeItem.target = handler

        menu.addItem(settingsItem)
        menu.addItem(actionItem1)
        menu.addItem(actionItem2)
        menu.addItem(glowItem)
        menu.addItem(memoryItem)
        menu.addItem(appearanceItem)
        menu.addItem(closeItem)

        return menu
    }
}

// MARK: - Handler (menu action receiver)

private final class Handler: NSObject {
    let currentAppearance: AppearanceMode
    let onSettings: () -> Void
    let onRotate: () -> Void
    let onSpin: () -> Void
    let onGlow: () -> Void
    let onMemory: () -> Void
    let onPulse: () -> Void
    let onExplode: () -> Void
    let onAppearance: (AppearanceMode) -> Void
    let onClose: () -> Void

    init(
        currentAppearance: AppearanceMode,
        onSettings: @escaping () -> Void,
        onRotate: @escaping () -> Void,
        onSpin: @escaping () -> Void,
        onGlow: @escaping () -> Void,
        onMemory: @escaping () -> Void,
        onPulse: @escaping () -> Void,
        onExplode: @escaping () -> Void,
        onAppearance: @escaping (AppearanceMode) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.currentAppearance = currentAppearance
        self.onSettings = onSettings
        self.onRotate = onRotate
        self.onSpin = onSpin
        self.onGlow = onGlow
        self.onMemory = onMemory
        self.onPulse = onPulse
        self.onExplode = onExplode
        self.onAppearance = onAppearance
        self.onClose = onClose
    }

    @objc func settingsClicked() { onSettings() }
    @objc func rotateClicked() { onRotate() }
    @objc func spinClicked() { onSpin() }
    @objc func glowClicked() { onGlow() }
    @objc func memoryClicked() { onMemory() }
    @objc func pulseClicked() { onPulse() }
    @objc func explodeClicked() { onExplode() }
    @objc func appearanceRingClicked() { onAppearance(.ring) }
    @objc func appearanceSphereClicked() { onAppearance(.particleSphere) }
    @objc func closeClicked() { onClose() }
}
