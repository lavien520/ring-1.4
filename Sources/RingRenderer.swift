import Cocoa

enum RingRenderer {
    // Safely extract RGB components from any NSColor (including catalog colors)
    private static func rgbComponents(from color: NSColor) -> (CGFloat, CGFloat, CGFloat) {
        let rgb = color.usingColorSpace(.genericRGB) ?? color
        return (rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
    }

    static func draw(in rect: CGRect, context: CGContext, ringSize: CGFloat, rotationAngle: CGFloat = 0, tiltAngle: CGFloat = 0, colorOverride: NSColor? = nil, glowIntensity: CGFloat = 1.0, showGap: Bool = false) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = ringSize / 2

        let (overrideR, overrideG, overrideB): (CGFloat, CGFloat, CGFloat) = if let color = colorOverride {
            rgbComponents(from: color)
        } else {
            (0, 0, 0)
        }

        // Arc angles: full circle or with gap at bottom
        let arcStart: CGFloat
        let arcEnd: CGFloat
        if showGap {
            let gap = 2 * .pi * Constants.arcGapFraction
            arcStart = -.pi / 2 + gap / 2
            arcEnd = -.pi / 2 + 2 * .pi - gap / 2
        } else {
            arcStart = 0
            arcEnd = 2 * .pi
        }

        for (index, layer) in Constants.ringLayers.enumerated() {
            let radius = baseRadius * layer.radius
            let layerAngle = rotationAngle * (1 + CGFloat(index) * 0.1)

            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: tiltAngle)
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
