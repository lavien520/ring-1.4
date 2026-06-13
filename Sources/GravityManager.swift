import Cocoa

protocol GravityManagerDelegate: AnyObject {
    func gravityNeedsDisplay()
    func gravityDidStart()
    func gravityDidStop()
}

final class GravityManager {
    weak var delegate: GravityManagerDelegate?

    private var velocity: CGVector = .zero
    private var isFalling = false
    private var timer: Timer?
    private var lastTime: TimeInterval = 0
    private var hasBounced = false
    private var floor: CGFloat = 0
    private var ringRadius: CGFloat = 0

    var tiltAngle: CGFloat = 0

    var isActive: Bool { isFalling }

    // MARK: - Public

    func startFall(window: NSWindow, initialVelocity: CGVector) {
        stop()

        velocity = initialVelocity
        isFalling = true
        hasBounced = false
        lastTime = ProcessInfo.processInfo.systemUptime
        ringRadius = Constants.defaultRingSize * Constants.outerRadiusFactor
        floor = detectFloor(window: window)

        delegate?.gravityDidStart()

        timer = Timer.scheduledTimer(withTimeInterval: Constants.animationFPS, repeats: true) { [weak self] _ in
            self?.tick(window: window)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isFalling = false
        velocity = .zero
    }

    // MARK: - Physics

    private func tick(window: NSWindow) {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - lastTime, 0.05)
        lastTime = now

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let windowSize = window.frame.size

        // Apply gravity (Y up in macOS coords)
        velocity.dy -= Constants.gravityAcceleration * CGFloat(dt)

        // Apply horizontal friction
        velocity.dx *= Constants.gravityFloorFriction

        // Update position
        var origin = window.frame.origin
        origin.x += velocity.dx * CGFloat(dt)
        origin.y += velocity.dy * CGFloat(dt)

        // Collision bounds: window origin where ring edge touches screen edge
        // Ring center = origin + windowSize/2, ring edge = center ± ringRadius
        let halfW = windowSize.width / 2
        let halfH = windowSize.height / 2
        let minX = screenFrame.minX - halfW + ringRadius
        let maxX = screenFrame.maxX - halfW - ringRadius
        let minY = floor - halfH + ringRadius
        let maxY = screenFrame.maxY - halfH - ringRadius

        // Bottom wall (floor / ground)
        if origin.y <= minY {
            origin.y = minY
            if velocity.dy < 0 {
                velocity.dy = -velocity.dy * Constants.gravityBounceCoeff
                hasBounced = true
            }
        }

        // Top wall (ceiling)
        if origin.y >= maxY {
            origin.y = maxY
            if velocity.dy > 0 {
                velocity.dy = -velocity.dy * Constants.gravityBounceCoeff
            }
        }

        // Left wall
        if origin.x <= minX {
            origin.x = minX
            if velocity.dx < 0 {
                velocity.dx = -velocity.dx * Constants.gravityBounceCoeff
            }
        }

        // Right wall
        if origin.x >= maxX {
            origin.x = maxX
            if velocity.dx > 0 {
                velocity.dx = -velocity.dx * Constants.gravityBounceCoeff
            }
        }

        // Settle check (only at bottom)
        if origin.y <= minY {
            let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
            if speed < Constants.gravityVelocityThreshold && hasBounced {
                settle(window: window, origin: origin)
                return
            }
        }

        // Update tilt angle
        tiltAngle += velocity.dx * Constants.gravityRotationFactor
        tiltAngle *= Constants.gravityRotationDamping

        window.setFrameOrigin(origin)
        delegate?.gravityNeedsDisplay()
    }

    private func settle(window: NSWindow, origin: CGPoint) {
        stop()
        tiltAngle = 0
        window.setFrameOrigin(origin)
        delegate?.gravityDidStop()
    }

    /// Calculate the window origin Y for the screen's bottom edge.
    private func detectFloor(window: NSWindow) -> CGFloat {
        guard let screen = NSScreen.main else { return 0 }
        return screen.frame.minY
    }
}
