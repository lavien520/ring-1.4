import Cocoa

enum RingRenderer {
    // Arc gap centered at bottom (-π/2)
    private static let arcGap: CGFloat = 2 * .pi * Constants.arcGapFraction
    private static let arcStart: CGFloat = -.pi / 2 + arcGap / 2
    private static let arcEnd: CGFloat = -.pi / 2 + 2 * .pi - arcGap / 2

    // Safely extract RGB components from any NSColor (including catalog colors)
    private static func rgbComponents(from color: NSColor) -> (CGFloat, CGFloat, CGFloat) {
        let rgb = color.usingColorSpace(.genericRGB) ?? color
        return (rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
    }

    static func draw(in rect: CGRect, context: CGContext, ringSize: CGFloat, rotationAngle: CGFloat = 0, colorOverride: NSColor? = nil, glowIntensity: CGFloat = 1.0) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = ringSize / 2

        let (overrideR, overrideG, overrideB): (CGFloat, CGFloat, CGFloat) = if let color = colorOverride {
            rgbComponents(from: color)
        } else {
            (0, 0, 0)
        }

        for (index, layer) in Constants.ringLayers.enumerated() {
            let radius = baseRadius * layer.radius
            let layerAngle = rotationAngle * (1 + CGFloat(index) * 0.1)

            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: layerAngle)

            // Glow pass
            let glowR = colorOverride != nil ? overrideR : 0
            let glowG = colorOverride != nil ? overrideG : Constants.glowColor.greenComponent
            let glowB = colorOverride != nil ? overrideB : Constants.glowColor.blueComponent

            let layerGlowColor = CGColor(red: glowR, green: glowG, blue: glowB, alpha: 0.8 * layer.alpha * glowIntensity)
            context.setShadow(offset: .zero, blur: layer.blurRadius * glowIntensity, color: layerGlowColor)
            context.setStrokeColor(layerGlowColor)
            context.setLineWidth(layer.lineWidth)
            context.addArc(center: .zero, radius: radius, startAngle: arcStart, endAngle: arcEnd, clockwise: false)
            context.strokePath()

            // Crisp stroke pass (same transform, no need to save/restore)
            let strokeR = colorOverride != nil ? overrideR : Constants.strokeColor.redComponent
            let strokeG = colorOverride != nil ? overrideG : Constants.strokeColor.greenComponent
            let strokeB = colorOverride != nil ? overrideB : Constants.strokeColor.blueComponent

            let layerStrokeColor = CGColor(red: strokeR, green: strokeG, blue: strokeB, alpha: layer.alpha)
            context.setShadow(offset: .zero, blur: 0)
            context.setStrokeColor(layerStrokeColor)
            context.setLineWidth(layer.lineWidth)
            context.addArc(center: .zero, radius: radius, startAngle: arcStart, endAngle: arcEnd, clockwise: false)
            context.strokePath()

            context.restoreGState()
        }
    }
}
