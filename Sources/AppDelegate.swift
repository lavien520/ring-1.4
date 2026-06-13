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
            showHookWarning(reason: "未找到 Claude Code 配置文件")
            return
        }

        guard let data = FileManager.default.contents(atPath: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any],
              !hooks.isEmpty else {
            showHookWarning(reason: "Claude Code Hook 未配置")
            return
        }

        // Check if Ring hooks specifically are present
        let hooksData = try? JSONSerialization.data(withJSONObject: hooks, options: [])
        let hooksString = hooksData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        if hooksString.contains("ring-hook") {
            print("[AppDelegate] ✅ Claude Code hooks configured")
        } else {
            showHookWarning(reason: "Ring Hook 未配置")
        }
    }

    private func showHookWarning(reason: String) {
        print("[AppDelegate] ⚠️ \(reason)")
        print("[AppDelegate]    运行 'make install' 或 './hooks/install-hooks.sh' 配置 Hook")

        // Show alert dialog with actionable instructions
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "RingGlow Hook 未配置"
            alert.informativeText = "\(reason)\n\n请在终端运行以下命令后重启 Claude Code：\n\nmake install"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "复制命令")
            alert.addButton(withTitle: "忽略")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("make install", forType: .string)
            }
        }
    }
}
