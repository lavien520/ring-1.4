import Cocoa

final class RingWindow: NSWindow {
    init(ringSize: CGFloat) {
        let padding = ringSize + Constants.strokeWidth + Constants.outerBlurMax * 2
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
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
}
