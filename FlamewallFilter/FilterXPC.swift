import Foundation
import os.log

final class FilterXPCListener: NSObject, NSXPCListenerDelegate {
    private let listener: NSXPCListener
    private let policyStore: PolicyStore
    private let log = OSLog(subsystem: FlamewallConstants.filterBundleID, category: "XPC")
    private var exported: FilterXPCService?

    init(policyStore: PolicyStore) {
        self.policyStore = policyStore
        self.listener = NSXPCListener(machServiceName: FlamewallXPC.machServiceName)
        super.init()
        listener.delegate = self
    }

    func start() {
        exported = FilterXPCService(policyStore: policyStore)
        listener.resume()
        os_log("XPC listener started", log: log, type: .info)
    }

    func stop() {
        listener.invalidate()
        exported = nil
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: FlamewallFilterXPCProtocol.self)
        newConnection.exportedObject = exported
        newConnection.resume()
        return true
    }
}

final class FilterXPCService: NSObject, FlamewallFilterXPCProtocol {
    private let policyStore: PolicyStore

    init(policyStore: PolicyStore) {
        self.policyStore = policyStore
    }

    func updatePolicy(_ data: Data, reply: @escaping (Bool) -> Void) {
        do {
            let policy = try JSONDecoder().decode(EffectivePolicy.self, from: data)
            policyStore.update(policy)
            reply(true)
        } catch {
            reply(false)
        }
    }

    func currentPolicy(reply: @escaping (Data?) -> Void) {
        let policy = policyStore.policy
        reply(try? JSONEncoder().encode(policy))
    }
}
