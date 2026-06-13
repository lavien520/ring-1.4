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

        // Check if Claude Code hooks are configured
        checkHooksConfiguration()
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

    private func checkHooksConfiguration() {
        let settingsPath = NSHomeDirectory() + "/.claude/settings.json"

        guard FileManager.default.fileExists(atPath: settingsPath) else {
            print("[AppDelegate] ⚠️ Claude Code settings not found at \(settingsPath)")
            print("[AppDelegate]    Run 'make install' or './hooks/install-hooks.sh' to configure hooks")
            return
        }

        guard let data = FileManager.default.contents(atPath: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any],
              !hooks.isEmpty else {
            print("[AppDelegate] ⚠️ Claude Code hooks not configured")
            print("[AppDelegate]    Run 'make install' or './hooks/install-hooks.sh' to configure hooks")
            return
        }

        // Check if Ring hooks specifically are present
        let hooksData = try? JSONSerialization.data(withJSONObject: hooks, options: [])
        let hooksString = hooksData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        if hooksString.contains("ring-hook") {
            print("[AppDelegate] ✅ Claude Code hooks configured")
        } else {
            print("[AppDelegate] ⚠️ Ring hooks not found in Claude Code settings")
            print("[AppDelegate]    Run 'make install' or './hooks/install-hooks.sh' to configure hooks")
        }
    }
}
