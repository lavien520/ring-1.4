import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var ringWindow: RingWindow?
    private var stateMonitor: StateMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = RingWindow(ringSize: Constants.defaultRingSize)
        let ringView = RingView(frame: window.contentView!.bounds)
        ringView.autoresizingMask = [.width, .height]
        ringView.ringSize = Constants.defaultRingSize

        window.contentView = ringView
        window.makeKeyAndOrderFront(nil)

        ringWindow = window

        // Start state monitor server
        startStateMonitor(ringView: ringView)
    }

    func applicationWillTerminate(_ notification: Notification) {
        stateMonitor?.stop()
    }

    private func startStateMonitor(ringView: RingView) {
        let monitor = StateMonitor()
        monitor.delegate = ringView
        ringView.stateMonitor = monitor
        stateMonitor = monitor

        do {
            try monitor.start()
            print("[AppDelegate] State monitor started on port 23334")
        } catch {
            print("[AppDelegate] Failed to start state monitor: \(error)")
        }
    }
}
