import Cocoa

final class SettingsWindowController: NSWindowController {
    private weak var ringView: RingView?
    private var slider: NSSlider!

    init(ringView: RingView) {
        self.ringView = ringView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.isReleasedWhenClosed = false

        super.init(window: window)

        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let label = NSTextField(labelWithString: "圆环大小")
        label.font = .systemFont(ofSize: 13)
        label.frame = NSRect(x: 20, y: 80, width: 80, height: 20)

        slider = NSSlider(value: Double(ringView?.ringSize ?? Constants.defaultRingSize),
                          minValue: Double(Constants.minRingSize),
                          maxValue: Double(Constants.maxRingSize),
                          target: self,
                          action: #selector(sliderChanged))
        slider.frame = NSRect(x: 20, y: 45, width: 280, height: 24)
        slider.isContinuous = true

        let doneButton = NSButton(title: "完成", target: self, action: #selector(doneClicked))
        doneButton.frame = NSRect(x: 230, y: 10, width: 70, height: 28)
        doneButton.bezelStyle = .rounded

        contentView.addSubview(label)
        contentView.addSubview(slider)
        contentView.addSubview(doneButton)
    }

    // MARK: - Actions

    @objc private func sliderChanged() {
        ringView?.ringSize = CGFloat(slider.doubleValue)
    }

    @objc private func doneClicked() {
        close()
    }
}
