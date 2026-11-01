import Foundation

@MainActor
final class UsageTracker: ObservableObject {
    @Published private(set) var bytesInPerSecond: Double = 0
    @Published private(set) var bytesOutPerSecond: Double = 0

    private let store: FlamewallStore
    private let networkMonitor: NetworkMonitor
    private var timer: Timer?
    private var lastSnapshot: InterfaceCounters.Snapshot?
    private var lastSampleDate: Date?
    private var lastSSID: String?
    private var saveThrottle: Date = .distantPast

    init(store: FlamewallStore, networkMonitor: NetworkMonitor) {
        self.store = store
        self.networkMonitor = networkMonitor
    }

    func start(interval: TimeInterval = 1.0) {
        stop()
        lastSnapshot = nil
        lastSampleDate = nil
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func resetCurrentNetwork() {
        guard let ssid = networkMonitor.currentSSID else { return }
        store.resetUsage(for: ssid)
    }

    private func tick() {
        networkMonitor.refresh()
        let ssid = networkMonitor.currentSSID
        let interfaceName = networkMonitor.wifiInterfaceName

        guard let ssid, let interfaceName,
              let snapshot = InterfaceCounters.snapshot(for: interfaceName)
        else {
            bytesInPerSecond = 0
            bytesOutPerSecond = 0
            lastSnapshot = nil
            lastSampleDate = nil
            lastSSID = ssid
            return
        }

        let now = Date()
        defer {
            lastSnapshot = snapshot
            lastSampleDate = now
            lastSSID = ssid
        }

        guard let previous = lastSnapshot,
              let previousDate = lastSampleDate,
              lastSSID == ssid
        else {
            bytesInPerSecond = 0
            bytesOutPerSecond = 0
            return
        }

        let elapsed = now.timeIntervalSince(previousDate)
        guard elapsed > 0 else { return }

        let deltaIn = snapshot.bytesIn &- previous.bytesIn
        let deltaOut = snapshot.bytesOut &- previous.bytesOut

        // Counter reset / wrap
        let safeIn = snapshot.bytesIn >= previous.bytesIn ? deltaIn : 0
        let safeOut = snapshot.bytesOut >= previous.bytesOut ? deltaOut : 0

        bytesInPerSecond = Double(safeIn) / elapsed
        bytesOutPerSecond = Double(safeOut) / elapsed

        if safeIn > 0 || safeOut > 0 {
            store.accumulateUsage(ssid: ssid, deltaIn: safeIn, deltaOut: safeOut, persist: now.timeIntervalSince(saveThrottle) >= 5)
            if now.timeIntervalSince(saveThrottle) >= 5 {
                saveThrottle = now
            }
        }
    }
}
