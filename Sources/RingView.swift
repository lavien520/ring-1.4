import Cocoa
import QuartzCore

final class RingView: NSView, StateMonitorDelegate {
    var ringSize: CGFloat = Constants.defaultRingSize {
        didSet {
            dsegFont = NSFont(name: "Orbitron-Bold", size: ringSize * 0.14)
            updateWindowSize()
            needsDisplay = true
        }
    }

    // Glow intensity (0.0 ~ 2.0, default 1.5)
    var glowIntensity: CGFloat = Constants.defaultGlowIntensity {
        didSet { needsDisplay = true }
    }

    // State monitoring
    private var currentAgentState: AgentState = .idle
    private var lastActiveAgent: String = ""
    weak var stateMonitor: StateMonitor?

    // Managers
    private let animationManager = AnimationManager()
    private let flashManager = FlashEffectManager()
    private let permissionManager = PermissionManager()
    private let glowPanelManager = GlowPanelManager()
    private let gravityManager = GravityManager()
    private let memoryMonitor = MemoryMonitor()
    private var settingsController: SettingsWindowController?

    // State tracking
    private var isStateDrivenRotation = false

    // Drag tracking for gravity
    private var dragPositions: [(origin: CGPoint, time: TimeInterval)] = []
    private var isDragging = false

    // Memory display
    private var memoryPercent: Int?
    private var memoryHideTimer: Timer?
    private var dsegFont: NSFont?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerCustomFonts()
        setupManagers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupManagers() {
        animationManager.delegate = self
        flashManager.delegate = self
        permissionManager.delegate = self
        glowPanelManager.delegate = self
        gravityManager.delegate = self

        memoryMonitor.onMemoryUpdate = { [weak self] percent in
            guard let self = self else { return }
            if percent >= Constants.memoryWarnThreshold {
                if self.memoryPercent == nil || self.memoryHideTimer != nil {
                    self.memoryPercent = percent
                    self.memoryHideTimer?.invalidate()
                    self.memoryHideTimer = nil
                    self.needsDisplay = true
                } else {
                    self.memoryPercent = percent
                }
            } else if percent < Constants.memoryClearThreshold {
                if self.memoryHideTimer == nil {
                    self.memoryPercent = nil
                    self.needsDisplay = true
                }
            }
        }
        memoryMonitor.startMonitoring(interval: Constants.memoryPollInterval)
    }

    private func registerCustomFonts() {
        guard let fontURL = Bundle.main.url(forResource: "Orbitron-Bold", withExtension: "ttf") else { return }
        var errorRef: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &errorRef)
        dsegFont = NSFont(name: "Orbitron-Bold", size: ringSize * 0.14)
    }

    // MARK: - Drawing

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        var colorOverride: NSColor? = nil
        if permissionManager.isShowing {
            colorOverride = Constants.permissionMainColor
        } else if flashManager.isFlashingRed {
            colorOverride = Constants.flashRedColor
        } else if flashManager.isFlashingGreen {
            colorOverride = Constants.flashGreenColor
        }

        let rotationAngle = animationManager.rotationAngle
        let spinAngle = animationManager.spinAngle
        let showGap = animationManager.isAnimating

        // Apply spin effect: scale X by cos(spinAngle) to simulate vertical axis rotation
        if animationManager.isSpinning {
            let scaleX = cos(spinAngle)
            context.saveGState()
            context.translateBy(x: bounds.midX, y: bounds.midY)
            context.scaleBy(x: scaleX, y: 1.0)
            context.translateBy(x: -bounds.midX, y: -bounds.midY)
            RingRenderer.draw(in: bounds, context: context, ringSize: ringSize, rotationAngle: rotationAngle, tiltAngle: gravityManager.tiltAngle, colorOverride: colorOverride, glowIntensity: glowIntensity, showGap: showGap)
            context.restoreGState()
        } else {
            RingRenderer.draw(in: bounds, context: context, ringSize: ringSize, rotationAngle: rotationAngle, tiltAngle: gravityManager.tiltAngle, colorOverride: colorOverride, glowIntensity: glowIntensity, showGap: showGap)
        }

        // Draw "Allow All" label on main ring during permission mode
        if permissionManager.isShowing {
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let label = "Allow All"
            let fontSize = ringSize * Constants.permissionLabelFontFactor
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
            let color = Constants.permissionMainColor
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
            ]
            let textSize = (label as NSString).size(withAttributes: attrs)
            let textRect = NSRect(
                x: center.x - textSize.width / 2,
                y: center.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )

            // Glow pass
            context.saveGState()
            let rgb = color.usingColorSpace(.genericRGB) ?? color
            let glowColor = CGColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent, alpha: 0.6)
            context.setShadow(offset: .zero, blur: fontSize * 0.8, color: glowColor)
            (label as NSString).draw(in: textRect, withAttributes: attrs)
            context.restoreGState()

            // Crisp text pass
            (label as NSString).draw(in: textRect, withAttributes: attrs)
        }

        // Draw memory percentage in ring center (DSEG7 digital font)
        if let percent = memoryPercent, !permissionManager.isShowing {
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let label = "\(percent)%"
            let fontSize = ringSize * 0.14
            let font = dsegFont ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
            let scaledFont = NSFont(descriptor: font.fontDescriptor, size: fontSize) ?? font
            let color: NSColor = percent >= 90 ? .systemRed : (percent >= 80 ? .systemYellow : .white)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: scaledFont,
                .foregroundColor: color,
            ]
            let textSize = (label as NSString).size(withAttributes: attrs)
            let textRect = NSRect(
                x: center.x - textSize.width / 2,
                y: center.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )

            // Glow pass
            context.saveGState()
            let rgb = color.usingColorSpace(.genericRGB) ?? color
            let glowColor = CGColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent, alpha: 0.6)
            context.setShadow(offset: .zero, blur: fontSize * 0.8, color: glowColor)
            (label as NSString).draw(in: textRect, withAttributes: attrs)
            context.restoreGState()

            // Crisp text pass
            (label as NSString).draw(in: textRect, withAttributes: attrs)
        }
    }

    // MARK: - Hit Testing (click-through on transparent areas)

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Check permission ring buttons first
        if let ring = permissionManager.hitTest(point, in: self) {
            return ring
        }

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        let baseRadius = ringSize / 2
        let outerRadius = baseRadius * Constants.outerRadiusFactor
            + Constants.permissionHitRadiusOffset
            + Constants.hitTestTolerance

        // In permission mode, check if click hits an Allow/Deny button first
        if permissionManager.isShowing {
            if let button = permissionManager.hitTest(point, in: self) {
                return button
            }
            // Click on main ring area (not a button) → default to allow
            if distance <= outerRadius {
                return self
            }
        }

        let innerRadius = baseRadius * Constants.innerRadiusFactor
            - Constants.permissionHitRadiusOffset
            - Constants.hitTestTolerance
        guard distance >= innerRadius && distance <= outerRadius else { return nil }
        return self
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        if permissionManager.isShowing {
            let point = convert(event.locationInWindow, from: nil)
            if let behavior = permissionManager.hitTestBehavior(point, in: self) {
                stateMonitor?.resolvePermission(behavior: behavior)
            } else {
                stateMonitor?.resolvePermission(behavior: "allow")
            }
            permissionManager.hide(from: self, window: window)
            updateWindowSize()
            return
        }
        if animationManager.isAnimating {
            animationManager.stopRotationAnimation()
        }

        // Stop any active gravity
        if gravityManager.isActive {
            gravityManager.stop()
        }

        // Start custom drag tracking
        isDragging = true
        dragPositions.removeAll()
        if let origin = window?.frame.origin {
            let now = ProcessInfo.processInfo.systemUptime
            dragPositions.append((origin: origin, time: now))
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let window = window else { return }

        var origin = window.frame.origin
        origin.x += event.deltaX
        origin.y -= event.deltaY
        window.setFrameOrigin(origin)

        let now = ProcessInfo.processInfo.systemUptime
        dragPositions.append((origin: origin, time: now))
        if dragPositions.count > 20 {
            dragPositions.removeFirst()
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false

        guard let window = window else { return }
        let currentOrigin = window.frame.origin
        let now = ProcessInfo.processInfo.systemUptime

        // Find a position ~100ms ago for velocity calculation
        var velocity = CGVector(dx: 0, dy: 0)
        for entry in dragPositions.reversed() {
            let dt = now - entry.time
            if dt >= 0.05 {
                velocity.dx = (currentOrigin.x - entry.origin.x) / CGFloat(dt)
                velocity.dy = (currentOrigin.y - entry.origin.y) / CGFloat(dt)
                break
            }
        }

        // Start gravity if speed is significant
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        if speed > 100 {
            gravityManager.startFall(window: window, initialVelocity: velocity)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)

        let menu = ContextMenuBuilder.build(
            onSettings: { [weak self] in self?.showSettings() },
            onRotate: { [weak self] in self?.animationManager.startRotationAnimation() },
            onSpin: { [weak self] in self?.animationManager.startSpinAnimation() },
            onGlow: { [weak self] in self?.glowPanelManager.showPanel(relativeTo: self?.window) },
            onMemory: { [weak self] in self?.showMemoryTemporarily() },
            onClose: { NSApp.terminate(nil) }
        )
        let locationInWindow = event.locationInWindow
        menu.popUp(positioning: nil, at: locationInWindow, in: self)
    }

    // MARK: - Settings

    private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(ringView: self)
        }
        settingsController?.showWindow(nil)
        settingsController?.window?.center()
    }

    // MARK: - Memory Display

    private func showMemoryTemporarily() {
        memoryPercent = memoryMonitor.currentUsage()
        needsDisplay = true

        memoryHideTimer?.invalidate()
        memoryHideTimer = Timer.scheduledTimer(withTimeInterval: Constants.memoryManualDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // Only hide if not in auto-warn mode
            if let percent = self.memoryPercent, percent < Constants.memoryWarnThreshold {
                self.memoryPercent = nil
            }
            self.memoryHideTimer = nil
            self.needsDisplay = true
        }
    }

    // MARK: - StateMonitorDelegate

    func stateMonitor(_ monitor: StateMonitor, didUpdateState state: AgentState, forAgent agentId: String) {
        let previousState = currentAgentState
        let previousAgent = lastActiveAgent
        currentAgentState = state
        lastActiveAgent = agentId
        let isOpenClaw = agentId == "openclaw"

        // When switching agent, stop the other agent's animation
        if previousAgent != agentId {
            if animationManager.isSpinning { animationManager.stopSpinAnimation() }
            if isStateDrivenRotation {
                isStateDrivenRotation = false
                animationManager.stopStateDrivenRotation()
            }
        }

        switch state {
        case .thinking, .working:
            if isOpenClaw {
                if !animationManager.isSpinning { animationManager.startSpinAnimation(continuous: true) }
            } else {
                if !isStateDrivenRotation {
                    isStateDrivenRotation = true
                    animationManager.startStateDrivenRotation()
                }
            }

        case .idle, .sleeping:
            if isOpenClaw {
                if animationManager.isSpinning {
                    animationManager.stopSpinAnimation()
                    flashManager.flashGreen(duration: Constants.greenFlashDurationLong)
                }
            } else {
                if isStateDrivenRotation {
                    isStateDrivenRotation = false
                    animationManager.stopStateDrivenRotation()
                    if previousState == .working || previousState == .thinking {
                        flashManager.flashGreen()
                    }
                }
            }

        case .attention:
            if isOpenClaw {
                if animationManager.isSpinning {
                    animationManager.stopSpinAnimation()
                    flashManager.flashGreen(duration: Constants.greenFlashDurationLong)
                }
            } else {
                if isStateDrivenRotation {
                    isStateDrivenRotation = false
                    animationManager.stopStateDrivenRotation()
                }
            }

        case .error:
            if isOpenClaw {
                if animationManager.isSpinning {
                    animationManager.stopSpinAnimation()
                    flashManager.flashRed()
                }
            } else {
                if isStateDrivenRotation {
                    isStateDrivenRotation = false
                    animationManager.stopStateDrivenRotation()
                }
            }

        case .notification:
            break
        }
    }

    func stateMonitor(_ monitor: StateMonitor, didReceivePermission toolName: String?, sessionId: String?) {
        permissionManager.show(in: self, window: window)
    }

    // MARK: - Window Resize

    func updateWindowSize() {
        guard let window = window else { return }
        let outerRadius = ringSize * Constants.outerRadiusFactor
        let maxBlur = Constants.outerBlurMax * CGFloat(Constants.glowSliderMax)
        let padding = outerRadius * 2 + maxBlur * 2 + Constants.strokeWidth
        let oldCenter = NSPoint(
            x: window.frame.midX,
            y: window.frame.midY
        )
        let newOrigin = NSPoint(
            x: oldCenter.x - padding / 2,
            y: oldCenter.y - padding / 2
        )
        window.setFrame(NSRect(origin: newOrigin, size: NSSize(width: padding, height: padding)), display: true)
    }
}

// MARK: - AnimationManagerDelegate

extension RingView: AnimationManagerDelegate {
    func animationNeedsDisplay() {
        needsDisplay = true
    }
}

// MARK: - FlashEffectManagerDelegate

extension RingView: FlashEffectManagerDelegate {
    func flashNeedsDisplay() {
        needsDisplay = true
    }
}

// MARK: - PermissionManagerDelegate

extension RingView: PermissionManagerDelegate {
    func permissionNeedsDisplay() {
        needsDisplay = true
    }

    func permissionResolve(behavior: String) {
        stateMonitor?.resolvePermission(behavior: behavior)
        updateWindowSize()
    }
}

// MARK: - GlowPanelManagerDelegate

extension RingView: GlowPanelManagerDelegate {}

// MARK: - GravityManagerDelegate

extension RingView: GravityManagerDelegate {
    func gravityNeedsDisplay() {
        needsDisplay = true
    }

    func gravityDidStart() {}

    func gravityDidStop() {
        needsDisplay = true
    }
}
