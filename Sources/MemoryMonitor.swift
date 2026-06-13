import Foundation

final class MemoryMonitor {
    var onMemoryUpdate: ((Int) -> Void)?

    private var timer: Timer?

    func startMonitoring(interval: TimeInterval = 5) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let percent = self.currentUsage()
            self.onMemoryUpdate?(percent)
        }
        // Fire immediately
        let percent = currentUsage()
        onMemoryUpdate?(percent)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func currentUsage() -> Int {
        let (used, total) = getMemoryUsage()
        guard total > 0 else { return 0 }
        return Int(Double(used) / Double(total) * 100)
    }

    private func getMemoryUsage() -> (used: UInt64, total: UInt64) {
        var info = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64()

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(info)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &info)
            }
        }

        guard result == KERN_SUCCESS else { return (0, 0) }

        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(stats.free_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        let used = active + wired + compressed
        let total = free + used + inactive

        return (used, total)
    }
}
