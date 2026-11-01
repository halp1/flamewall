import Foundation
import CoreWLAN

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var currentSSID: String?
    @Published private(set) var wifiInterfaceName: String?

    private var timer: Timer?

    init() {
        refresh()
    }

    func start(interval: TimeInterval = 2.0) {
        stop()
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let client = CWWiFiClient.shared()
        let interface = client.interface()
        wifiInterfaceName = interface?.interfaceName
        let ssid = interface?.ssid()
        // Pause accrual when disconnected / no SSID
        currentSSID = (ssid?.isEmpty == false) ? ssid : nil
    }
}
