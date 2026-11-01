import Foundation
import NetworkExtension
import os.log
import Security

final class FilterDataProvider: NEFilterDataProvider {
    private let log = OSLog(subsystem: FlamewallConstants.filterBundleID, category: "Filter")
    private let policyStore = PolicyStore.shared
    private var xpcListener: FilterXPCListener?

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting Flamewall filter", log: log, type: .info)
        policyStore.loadFromDisk()
        xpcListener = FilterXPCListener(policyStore: policyStore)
        xpcListener?.start()
        completionHandler(nil)
    }

    override func stopFilter(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        os_log("Stopping Flamewall filter: %{public}d", log: log, type: .info, reason.rawValue)
        xpcListener?.stop()
        xpcListener = nil
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let bundleID = Self.bundleID(for: flow)
        let policy = policyStore.policy
        let allowed = RuleEvaluator.allows(bundleID: bundleID, policy: policy)
        return allowed ? .allow() : .drop()
    }

    private static func bundleID(for flow: NEFilterFlow) -> String? {
        guard let tokenData = flow.sourceAppAuditToken else { return nil }
        return signingIdentifier(fromAuditToken: tokenData)
    }

    private static func signingIdentifier(fromAuditToken auditToken: Data) -> String? {
        let attributes: [CFString: Any] = [
            kSecGuestAttributeAudit: auditToken
        ]
        var code: SecCode?
        let status = SecCodeCopyGuestWithAttributes(
            nil,
            attributes as CFDictionary,
            [],
            &code
        )
        guard status == errSecSuccess, let code else { return nil }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode
        else { return nil }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(), &info) == errSecSuccess,
              let info = info as? [String: Any],
              let identifier = info[kSecCodeInfoIdentifier as String] as? String
        else { return nil }

        return identifier
    }
}
