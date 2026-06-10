import Cocoa

protocol GlowPanelManagerDelegate: AnyObject {
    var glowIntensity: CGFloat { get set }
}

final class GlowPanelManager {
    weak var delegate: GlowPanelManagerDelegate?
    private var panel: NSWindow?

    func showPanel(relativeTo parentWindow: NSWindow?) {
        closePanel()

        let panelWidth: CGFloat = 260
        let panelHeight: CGFloat = 80
        let offset: CGFloat = 20

        guard let parentWindow = parentWindow else { return }
        let parentFrame = parentWindow.frame
        let panelOrigin = NSPoint(
            x: parentFrame.midX - panelWidth / 2,
            y: parentFrame.maxY + offset
        )

        let newPanel = NSWindow(
            contentRect: NSRect(origin: panelOrigin, size: NSSize(width: panelWidth, height: panelHeight)),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newPanel.title = "发光强度"
        newPanel.isReleasedWhenClosed = false
        newPanel.level = .floating

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))

        // Label
        let label = NSTextField(frame: NSRect(x: 15, y: 48, width: 230, height: 18))
        label.stringValue = "调节圆环发光强度"
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        contentView.addSubview(label)

        // Slider
        let slider = NSSlider(frame: NSRect(x: 15, y: 15, width: 190, height: 24))
        slider.minValue = Constants.glowSliderMin
        slider.maxValue = Constants.glowSliderMax
        slider.doubleValue = Double(delegate?.glowIntensity ?? Constants.defaultGlowIntensity)
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.isContinuous = true
        contentView.addSubview(slider)

        // Value label
        let valueLabel = NSTextField(frame: NSRect(x: 210, y: 15, width: 40, height: 24))
        valueLabel.stringValue = String(format: "%.0f%%", (delegate?.glowIntensity ?? Constants.defaultGlowIntensity) * 100)
        valueLabel.isEditable = false
        valueLabel.isBordered = false
        valueLabel.drawsBackground = false
        valueLabel.textColor = .labelColor
        valueLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        valueLabel.alignment = .right
        valueLabel.tag = 100
        contentView.addSubview(valueLabel)

        newPanel.contentView = contentView
        newPanel.makeKeyAndOrderFront(nil)

        panel = newPanel
    }

    func closePanel() {
        panel?.close()
        panel = nil
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        delegate?.glowIntensity = CGFloat(sender.doubleValue)
        if let contentView = panel?.contentView,
           let valueLabel = contentView.viewWithTag(100) as? NSTextField {
            valueLabel.stringValue = String(format: "%.0f%%", CGFloat(sender.doubleValue) * 100)
        }
    }
}
