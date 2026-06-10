import Cocoa
import QuartzCore

final class RingView: NSView, StateMonitorDelegate {
    var ringSize: CGFloat = Constants.defaultRingSize {
        didSet {
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
    private var settingsController: SettingsWindowController?

    // State tracking
    private var isStateDrivenRotation = false

    override init(frame: NSRect) {
        super.init(frame: frame)
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

        // Apply spin effect: scale X by cos(spinAngle) to simulate vertical axis rotation
        if animationManager.isSpinning {
            let scaleX = cos(spinAngle)
            context.saveGState()
            context.translateBy(x: bounds.midX, y: bounds.midY)
            context.scaleBy(x: scaleX, y: 1.0)
            context.translateBy(x: -bounds.midX, y: -bounds.midY)
            RingRenderer.draw(in: bounds, context: context, ringSize: ringSize, rotationAngle: rotationAngle, colorOverride: colorOverride, glowIntensity: glowIntensity)
            context.restoreGState()
        } else {
            RingRenderer.draw(in: bounds, context: context, ringSize: ringSize, rotationAngle: rotationAngle, colorOverride: colorOverride, glowIntensity: glowIntensity)
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

        // In permission mode, entire ring area (including interior) is clickable
        if permissionManager.isShowing && distance <= outerRadius {
            return self
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
            stateMonitor?.resolvePermission(behavior: "allow")
            permissionManager.hide(from: self, window: window)
            updateWindowSize()
            return
        }
        if animationManager.isAnimating {
            animationManager.stopRotationAnimation()
        }
        window?.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)

        let menu = ContextMenuBuilder.build(
            onSettings: { [weak self] in self?.showSettings() },
            onRotate: { [weak self] in self?.animationManager.startRotationAnimation() },
            onSpin: { [weak self] in self?.animationManager.startSpinAnimation() },
            onGlow: { [weak self] in self?.glowPanelManager.showPanel(relativeTo: self?.window) },
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
        let padding = outerRadius * 2 + Constants.outerBlurMax * 2 + Constants.strokeWidth
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
