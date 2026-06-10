import Cocoa

enum Constants {
    // MARK: - Ring Dimensions

    static let defaultRingSize: CGFloat = 140
    static let minRingSize: CGFloat = 20
    static let maxRingSize: CGFloat = 400
    static let strokeWidth: CGFloat = 4.8
    static let hitTestTolerance: CGFloat = 10

    // MARK: - Ring Layers (multi-layer glow effect)

    struct RingLayerConfig {
        let radius: CGFloat
        let lineWidth: CGFloat
        let alpha: CGFloat
        let blurRadius: CGFloat
    }

    static let ringLayers: [RingLayerConfig] = [
        RingLayerConfig(radius: 0.50, lineWidth: 3, alpha: 0.9, blurRadius: 15),
        RingLayerConfig(radius: 0.55, lineWidth: 2, alpha: 0.6, blurRadius: 25),
        RingLayerConfig(radius: 0.60, lineWidth: 1, alpha: 0.3, blurRadius: 35),
    ]

    /// Arc gap as fraction of circumference (2%)
    static let arcGapFraction: CGFloat = 0.02

    // MARK: - Animation

    static let rotationAcceleration: CGFloat = 0.0004
    static let rotationMaxSpeed: CGFloat = 0.30
    static let rotationDuration: TimeInterval = 5.0
    static let spinSpeed: CGFloat = 0.08
    static let spinDuration: TimeInterval = 3.0
    static let animationFPS: TimeInterval = 1.0 / 60.0

    // MARK: - Flash Effects

    static let greenFlashDuration: TimeInterval = 2.0
    static let greenFlashDurationLong: TimeInterval = 3.0
    static let redFlashDuration: TimeInterval = 5.0

    // MARK: - Permission UI

    static let permissionGap: CGFloat = 2
    static let permissionOuterRadiusFactor: CGFloat = 0.30
    static let permissionPadding: CGFloat = 60
    static let permissionLabelFontFactor: CGFloat = 0.12
    static let permissionHitRadiusOffset: CGFloat = 35
    static let permissionHitRadiusExtra: CGFloat = 20

    // MARK: - Glow

    static let defaultGlowIntensity: CGFloat = 1.5
    static let glowSliderMin: Double = 0.0
    static let glowSliderMax: Double = 2.0

    // MARK: - Layout

    static let outerRadiusFactor: CGFloat = 0.60
    static let innerRadiusFactor: CGFloat = 0.50
    static let outerBlurMax: CGFloat = 35

    // MARK: - Colors

    static let glowColor = NSColor(red: 0, green: 0.749, blue: 1.0, alpha: 1.0)
    static let strokeColor = NSColor(red: 0.529, green: 0.808, blue: 0.98, alpha: 1.0)
    static let permissionAllowColor = NSColor.systemGreen
    static let permissionDenyColor = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
    static let permissionMainColor = NSColor.systemBlue
    static let flashGreenColor = NSColor.systemGreen
    static let flashRedColor = NSColor.systemRed

    // MARK: - Server

    static let serverPort: UInt16 = 23334
}
