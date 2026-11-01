import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let store: FlamewallStore
    let networkMonitor: NetworkMonitor
    let usageTracker: UsageTracker
    let filterController: FilterController
    let loginItem: LoginItemService

    @Published var showSettings = false

    init() {
        let store = FlamewallStore()
        let networkMonitor = NetworkMonitor()
        self.store = store
        self.networkMonitor = networkMonitor
        self.usageTracker = UsageTracker(store: store, networkMonitor: networkMonitor)
        self.filterController = FilterController()
        self.loginItem = LoginItemService()
    }

    var activeResolution: (profile: FilterProfile, source: ProfileSource) {
        ProfileResolver.resolve(config: store.config, ssid: networkMonitor.currentSSID)
    }

    var effectivePolicy: EffectivePolicy {
        ProfileResolver.effectivePolicy(config: store.config, ssid: networkMonitor.currentSSID)
    }

    func start() {
        networkMonitor.start()
        usageTracker.start()
        pushPolicy()
        Task {
            await filterController.refreshConfigurationState()
        }
    }

    func pushPolicy() {
        filterController.pushPolicy(effectivePolicy)
    }

    func toggleFilterEnabled(_ enabled: Bool) {
        let source = activeResolution.source
        store.updateConfig { config in
            switch source {
            case .global:
                config.global.enabled = enabled
            case .network(let ssid):
                var profile = config.networks[ssid] ?? FilterProfile()
                profile.enabled = enabled
                config.networks[ssid] = profile
            }
        }
        pushPolicy()
    }

    func setMode(_ mode: FilterMode) {
        let source = activeResolution.source
        store.updateConfig { config in
            switch source {
            case .global:
                config.global.mode = mode
            case .network(let ssid):
                var profile = config.networks[ssid] ?? FilterProfile()
                profile.mode = mode
                config.networks[ssid] = profile
            }
        }
        pushPolicy()
    }

    func addApp(_ app: AppIdentity) {
        store.addApp(app, to: activeResolution.source)
        pushPolicy()
    }

    func removeApp(bundleID: String) {
        store.removeApp(bundleID: bundleID, from: activeResolution.source)
        pushPolicy()
    }
}
