import Cocoa

protocol FlashEffectManagerDelegate: AnyObject {
    func flashNeedsDisplay()
}

final class FlashEffectManager {
    weak var delegate: FlashEffectManagerDelegate?

    private(set) var isFlashingGreen = false
    private(set) var isFlashingRed = false
    private var greenTimer: Timer?
    private var redTimer: Timer?

    deinit {
        greenTimer?.invalidate()
        redTimer?.invalidate()
    }

    func flashGreen(duration: TimeInterval = Constants.greenFlashDuration) {
        greenTimer?.invalidate()
        isFlashingGreen = true
        delegate?.flashNeedsDisplay()

        greenTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.isFlashingGreen = false
            self?.delegate?.flashNeedsDisplay()
        }
    }

    func flashRed(duration: TimeInterval = Constants.redFlashDuration) {
        redTimer?.invalidate()
        isFlashingRed = true
        delegate?.flashNeedsDisplay()

        redTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.isFlashingRed = false
            self?.delegate?.flashNeedsDisplay()
        }
    }

    func stopAll() {
        greenTimer?.invalidate()
        greenTimer = nil
        redTimer?.invalidate()
        redTimer = nil
        isFlashingGreen = false
        isFlashingRed = false
    }
}
