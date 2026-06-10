import Cocoa

final class PermissionRingButton: NSView {
    var onTap: ((String) -> Void)?

    private let ringSize: CGFloat
    private let ringColor: NSColor
    private let label: String
    private let behavior: String

    init(center: CGPoint, radius: CGFloat, color: NSColor, label: String, behavior: String) {
        self.ringSize = radius
        self.ringColor = color
        self.label = label
        self.behavior = behavior

        let padding = radius + Constants.permissionPadding
        let frame = NSRect(
            x: center.x - padding,
            y: center.y - padding,
            width: padding * 2,
            height: padding * 2
        )
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw ring using same renderer as main ring
        RingRenderer.draw(in: bounds, context: context, ringSize: ringSize, rotationAngle: 0, colorOverride: ringColor)

        // Draw label text centered on the ring
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let fontSize = ringSize * Constants.permissionLabelFontFactor
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: ringColor,
        ]
        let textSize = (label as NSString).size(withAttributes: attrs)
        let textRect = NSRect(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        (label as NSString).draw(in: textRect, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        alphaValue = 0.7
    }

    override func mouseUp(with event: NSEvent) {
        alphaValue = 1.0
        let point = convert(event.locationInWindow, from: nil)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let outerRadius = ringSize * Constants.outerRadiusFactor
            + Constants.permissionHitRadiusOffset
            + Constants.permissionHitRadiusExtra

        if distance <= outerRadius {
            onTap?(behavior)
        }
    }
}
