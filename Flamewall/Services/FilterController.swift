import Foundation
import NetworkExtension
import SystemExtensions

enum FilterExtensionStatus: Equatable, Sendable {
    case unknown
    case waitingForApproval
    case approved
    case active
    case failed(String)

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .waitingForApproval: return "Waiting for approval"
        case .approved: return "Approved"
        case .active: return "Active"
        case .failed(let message): return "Failed: \(message)"
        }
    }
}

@MainActor
final class FilterController: NSObject, ObservableObject {
    @Published private(set) var status: FilterExtensionStatus = .unknown
    @Published private(set) var filterConfigurationEnabled: Bool = false

    private var activationRequest: OSSystemExtensionRequest?
    private let xpcClient = FilterXPCClient()

    func refreshConfigurationState() async {
        do {
            let manager = NEFilterManager.shared()
            try await manager.loadFromPreferences()
            filterConfigurationEnabled = manager.isEnabled
            if manager.isEnabled {
                if case .failed = status { } else {
                    status = .active
                }
            }
        } catch {
            // Preferences may be empty before first save
            filterConfigurationEnabled = false
        }
    }

    func activateExtension() {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: FlamewallConstants.filterBundleID,
            queue: .main
        )
        request.delegate = self
        activationRequest = request
        status = .waitingForApproval
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func enableFilterConfiguration() async {
        do {
            let manager = NEFilterManager.shared()
            try await manager.loadFromPreferences()

            if manager.providerConfiguration == nil {
                let config = NEFilterProviderConfiguration()
                config.filterSockets = true
                config.filterPackets = false
                config.username = "Flamewall"
                config.organization = "Flamewall"
                manager.providerConfiguration = config
            }

            manager.localizedDescription = "Flamewall"
            manager.isEnabled = true
            try await manager.saveToPreferences()
            filterConfigurationEnabled = true
            status = .active
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func disableFilterConfiguration() async {
        do {
            let manager = NEFilterManager.shared()
            try await manager.loadFromPreferences()
            manager.isEnabled = false
            try await manager.saveToPreferences()
            filterConfigurationEnabled = false
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func pushPolicy(_ policy: EffectivePolicy) {
        xpcClient.updatePolicy(policy)
    }
}

extension FilterController: OSSystemExtensionRequestDelegate {
    nonisolated func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension extension: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    nonisolated func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        Task { @MainActor in
            self.status = .waitingForApproval
        }
    }

    nonisolated func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        Task { @MainActor in
            switch result {
            case .completed:
                self.status = .approved
                await self.enableFilterConfiguration()
            case .willCompleteAfterReboot:
                self.status = .waitingForApproval
            @unknown default:
                self.status = .approved
            }
        }
    }

    nonisolated func request(
        _ request: OSSystemExtensionRequest,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.status = .failed(error.localizedDescription)
        }
    }
}

final class FilterXPCClient {
    private var connection: NSXPCConnection?

    func updatePolicy(_ policy: EffectivePolicy) {
        let conn = ensureConnection()
        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
            NSLog("Flamewall XPC error: \(error)")
        }) as? FlamewallFilterXPCProtocol else {
            return
        }
        do {
            let data = try JSONEncoder().encode(policy)
            proxy.updatePolicy(data) { _ in }
        } catch {
            NSLog("Flamewall encode policy failed: \(error)")
        }
    }

    private func ensureConnection() -> NSXPCConnection {
        if let connection { return connection }
        let connection = NSXPCConnection(machServiceName: FlamewallXPC.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: FlamewallFilterXPCProtocol.self)
        connection.resume()
        self.connection = connection
        return connection
    }
}
