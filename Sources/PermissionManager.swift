import Cocoa

protocol PermissionManagerDelegate: AnyObject {
    var ringSize: CGFloat { get }
    func permissionNeedsDisplay()
    func permissionResolve(behavior: String)
}

final class PermissionManager {
    weak var delegate: PermissionManagerDelegate?

    private(set) var isShowing = false
    private var permissionRings: [PermissionRingButton] = []

    var ringButtons: [PermissionRingButton] { permissionRings }

    // MARK: - Show Permission Rings

    func show(in parentView: NSView, window: NSWindow?) {
        guard !isShowing else { return }
        isShowing = true

        guard let delegate = delegate else { return }
        let ringSize = delegate.ringSize

        let gap = Constants.permissionGap
        let outerR = ringSize * Constants.permissionOuterRadiusFactor
        let step = outerR * 2 + gap

        // Save main ring's screen position before expanding
        let mainCenterX = parentView.bounds.midX
        let mainCenterY = parentView.bounds.midY
        guard let windowFrame = window?.frame else { return }
        let mainScreenX = windowFrame.origin.x + mainCenterX
        let mainScreenY = windowFrame.origin.y + mainCenterY

        // Check space in all four directions
        guard let screenFrame = window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let spaceLeft = mainScreenX - screenFrame.origin.x
        let spaceRight = (screenFrame.origin.x + screenFrame.width) - mainScreenX
        let spaceUp = (screenFrame.origin.y + screenFrame.height) - mainScreenY
        let spaceDown = mainScreenY - screenFrame.origin.y

        let leftOK = spaceLeft >= step
        let rightOK = spaceRight >= step
        let upOK = spaceUp >= step
        let downOK = spaceDown >= step

        // Decide placement: prefer left+right, then up+down, then mix
        let dir1: CGPoint
        let dir2: CGPoint
        let expandH: Bool
        let expandV: Bool

        if leftOK && rightOK {
            dir1 = CGPoint(x: -step, y: 0)
            dir2 = CGPoint(x: step, y: 0)
            expandH = true; expandV = false
        } else if upOK && downOK {
            dir1 = CGPoint(x: 0, y: step)
            dir2 = CGPoint(x: 0, y: -step)
            expandH = false; expandV = true
        } else if rightOK && upOK {
            dir1 = CGPoint(x: step, y: 0)
            dir2 = CGPoint(x: 0, y: step)
            expandH = true; expandV = true
        } else if rightOK && downOK {
            dir1 = CGPoint(x: step, y: 0)
            dir2 = CGPoint(x: 0, y: -step)
            expandH = true; expandV = true
        } else if leftOK && upOK {
            dir1 = CGPoint(x: -step, y: 0)
            dir2 = CGPoint(x: 0, y: step)
            expandH = true; expandV = true
        } else if leftOK && downOK {
            dir1 = CGPoint(x: -step, y: 0)
            dir2 = CGPoint(x: 0, y: -step)
            expandH = true; expandV = true
        } else {
            dir1 = CGPoint(x: step, y: 0)
            dir2 = CGPoint(x: 0, y: -step)
            expandH = true; expandV = true
        }

        // Expand window to fit
        expandWindow(window: window, horizontal: expandH, vertical: expandV, ringSize: ringSize)

        // Convert main ring's screen position to new view coords
        let newWindowFrame = window?.frame ?? windowFrame
        let mainX = mainScreenX - newWindowFrame.origin.x
        let mainY = mainScreenY - newWindowFrame.origin.y

        let configs: [(String, NSColor, String, CGPoint)] = [
            ("Allow", Constants.permissionAllowColor, "allow",
             CGPoint(x: mainX + dir1.x, y: mainY + dir1.y)),
            ("Deny", Constants.permissionDenyColor, "deny",
             CGPoint(x: mainX + dir2.x, y: mainY + dir2.y)),
        ]

        for (label, color, behavior, center) in configs {
            let btn = PermissionRingButton(
                center: center,
                radius: ringSize,
                color: color,
                label: label,
                behavior: behavior
            )
            btn.onTap = { [weak self] behavior in
                self?.delegate?.permissionResolve(behavior: behavior)
                self?.hide(from: parentView, window: window)
            }
            parentView.addSubview(btn)
            permissionRings.append(btn)
        }

        delegate.permissionNeedsDisplay()
    }

    // MARK: - Hide Permission Rings

    func hide(from parentView: NSView, window: NSWindow?) {
        isShowing = false
        permissionRings.forEach { $0.removeFromSuperview() }
        permissionRings.removeAll()
        delegate?.permissionNeedsDisplay()
    }

    // MARK: - Hit Test

    func hitTest(_ point: NSPoint, in parentView: NSView) -> NSView? {
        guard isShowing, let delegate = delegate else { return nil }
        let ringSize = delegate.ringSize

        for ring in permissionRings {
            let localPoint = ring.convert(point, from: parentView)
            let center = CGPoint(x: ring.bounds.midX, y: ring.bounds.midY)
            let dx = localPoint.x - center.x
            let dy = localPoint.y - center.y
            let distance = sqrt(dx * dx + dy * dy)
            let outerRadius = ringSize * Constants.outerRadiusFactor
                + Constants.permissionHitRadiusOffset
                + Constants.permissionHitRadiusExtra
            if distance <= outerRadius {
                return ring
            }
        }
        return nil
    }

    /// Returns the behavior string ("allow"/"deny") if point hits a button, nil otherwise.
    func hitTestBehavior(_ point: NSPoint, in parentView: NSView) -> String? {
        guard isShowing, let delegate = delegate else { return nil }
        let ringSize = delegate.ringSize

        for ring in permissionRings {
            let localPoint = ring.convert(point, from: parentView)
            let center = CGPoint(x: ring.bounds.midX, y: ring.bounds.midY)
            let dx = localPoint.x - center.x
            let dy = localPoint.y - center.y
            let distance = sqrt(dx * dx + dy * dy)
            let outerRadius = ringSize * Constants.outerRadiusFactor
                + Constants.permissionHitRadiusOffset
                + Constants.permissionHitRadiusExtra
            if distance <= outerRadius {
                return ring.behavior
            }
        }
        return nil
    }

    // MARK: - Window Expansion

    private func expandWindow(window: NSWindow?, horizontal: Bool, vertical: Bool, ringSize: CGFloat) {
        guard let window = window else { return }
        let step = ringSize * Constants.permissionOuterRadiusFactor * 2
            + Constants.permissionGap
            + Constants.permissionPadding

        let currentFrame = window.frame
        var newWidth = currentFrame.width
        var newHeight = currentFrame.height
        if horizontal { newWidth += step }
        if vertical { newHeight += step }

        let newOrigin = NSPoint(
            x: currentFrame.midX - newWidth / 2,
            y: currentFrame.midY - newHeight / 2
        )
        window.setFrame(NSRect(origin: newOrigin, size: NSSize(width: newWidth, height: newHeight)), display: true)
    }
}
