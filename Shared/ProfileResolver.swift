import Foundation

public enum ProfileResolver {
    /// Per-network overrides global when an SSID entry exists; otherwise global.
    public static func resolve(config: FlamewallConfig, ssid: String?) -> (profile: FilterProfile, source: ProfileSource) {
        if let ssid, let networkProfile = config.networks[ssid] {
            return (networkProfile, .network(ssid))
        }
        return (config.global, .global)
    }

    public static func effectivePolicy(config: FlamewallConfig, ssid: String?) -> EffectivePolicy {
        let (profile, _) = resolve(config: config, ssid: ssid)
        return EffectivePolicy.from(profile: profile)
    }
}

public enum ProfileSource: Equatable, Sendable {
    case global
    case network(String)

    public var displayName: String {
        switch self {
        case .global:
            return "Global"
        case .network(let ssid):
            return "Network: \(ssid)"
        }
    }
}
