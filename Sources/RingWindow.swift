import Cocoa

final class RingWindow: NSWindow {
    init(ringSize: CGFloat) {
        let maxBlur = Constants.outerBlurMax * CGFloat(Constants.glowSliderMax)
        let padding = ringSize + Constants.strokeWidth + maxBlur * 2
        let screenSize = NSScreen.main?.frame.size ?? NSSize(width: 1440, height: 900)
        let origin = NSPoint(
            x: (screenSize.width - padding) / 2,
            y: (screenSize.height - padding) / 2
        )

        super.init(
            contentRect: NSRect(origin: origin, size: NSSize(width: padding, height: padding)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = .canJoinAllSpaces
        isReleasedWhenClosed = false

        // Monitor fullscreen apps to hide ring when needed
        setupFullscreenMonitor()
    }

    override var canBecomeKey: Bool { true }

    // MARK: - Fullscreen Monitor

    private func setupFullscreenMonitor() {
        // Check fullscreen state when any app activates
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(checkFullscreenState),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Also check when apps launch or quit
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(checkFullscreenState),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(checkFullscreenState),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        // Initial check
        checkFullscreenState()
    }

    @objc private func checkFullscreenState() {
        // Use CGWindowList to check if any app has fullscreen windows
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            self.alphaValue = 1
            return
        }

        let ringPID = NSRunningApplication.current.processIdentifier

        for windowInfo in windowList {
            // Skip our own windows
            if let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
               ownerPID == ringPID {
                continue
            }

            // Check if window is fullscreen (layer 1000 is typical for fullscreen)
            if let windowLayer = windowInfo["kCGWindowLayer"] as? Int,
               windowLayer >= 1000 {
                // Check if it's a regular app window (not system UI)
                if let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                   !ownerName.isEmpty {
                    self.alphaValue = 0
                    return
                }
            }
        }

        self.alphaValue = 1
    }
}
