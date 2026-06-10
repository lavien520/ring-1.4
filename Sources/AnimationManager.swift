import Cocoa
import QuartzCore

protocol AnimationManagerDelegate: AnyObject {
    func animationNeedsDisplay()
}

final class AnimationManager {
    weak var delegate: AnimationManagerDelegate?

    // Rotation state
    private(set) var rotationAngle: CGFloat = 0
    private var rotationSpeed: CGFloat = 0.01
    private(set) var isAnimating = false
    private var isStateDrivenAnimation = false
    private var animationStartTime: CFTimeInterval = 0

    // Spin state
    private(set) var spinAngle: CGFloat = 0
    private(set) var isSpinning = false
    private var isStateDrivenSpin = false

    // Timers
    private var animationTimer: Timer?
    private var spinTimer: Timer?

    deinit {
        stopAnimationTimer()
        spinTimer?.invalidate()
    }

    // MARK: - Rotation Animation

    func startRotationAnimation() {
        if isAnimating {
            stopRotationAnimation()
            return
        }

        isAnimating = true
        rotationAngle = 0
        rotationSpeed = 0.01
        animationStartTime = CACurrentMediaTime()

        startAnimationTimer()
    }

    func stopRotationAnimation() {
        isAnimating = false
        stopAnimationTimer()
        rotationAngle = 0
        rotationSpeed = 0.01
        delegate?.animationNeedsDisplay()
    }

    func startStateDrivenRotation() {
        guard !isAnimating else { return }

        isAnimating = true
        isStateDrivenAnimation = true
        rotationAngle = 0
        rotationSpeed = 0.01

        startAnimationTimer()
    }

    func stopStateDrivenRotation() {
        isAnimating = false
        isStateDrivenAnimation = false
        stopAnimationTimer()
        rotationAngle = 0
        rotationSpeed = 0.01
        delegate?.animationNeedsDisplay()
    }

    var isStateDrivenRotation: Bool {
        isAnimating && isStateDrivenAnimation
    }

    // MARK: - Spin Animation

    func startSpinAnimation(continuous: Bool = false) {
        guard !isSpinning else { return }
        isSpinning = true
        isStateDrivenSpin = continuous
        spinAngle = 0

        let startTime = CACurrentMediaTime()
        spinTimer = Timer.scheduledTimer(withTimeInterval: Constants.animationFPS, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.isStateDrivenSpin {
                let elapsed = CACurrentMediaTime() - startTime
                if elapsed >= Constants.spinDuration {
                    self.stopSpinAnimation()
                    return
                }
            }
            self.spinAngle += Constants.spinSpeed
            self.delegate?.animationNeedsDisplay()
        }
    }

    func stopSpinAnimation() {
        isSpinning = false
        isStateDrivenSpin = false
        spinAngle = 0
        spinTimer?.invalidate()
        spinTimer = nil
        delegate?.animationNeedsDisplay()
    }

    // MARK: - Timer Management

    private func startAnimationTimer() {
        stopAnimationTimer()
        animationTimer = Timer.scheduledTimer(withTimeInterval: Constants.animationFPS, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }

    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateAnimation() {
        guard isAnimating else { return }

        // Manual rotation has a time limit; state-driven rotation is continuous
        if !isStateDrivenAnimation {
            let elapsed = CACurrentMediaTime() - animationStartTime
            if elapsed >= Constants.rotationDuration {
                stopRotationAnimation()
                return
            }
        }

        // Gradually accelerate
        if rotationSpeed < Constants.rotationMaxSpeed {
            rotationSpeed += Constants.rotationAcceleration
        }
        rotationAngle -= rotationSpeed

        delegate?.animationNeedsDisplay()
    }
}
