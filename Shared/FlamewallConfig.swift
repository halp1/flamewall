import Foundation

public struct FlamewallConfig: Codable, Equatable, Sendable {
    public var global: FilterProfile
    /// Per-network profiles keyed by Wi-Fi SSID.
    public var networks: [String: FilterProfile]

    public init(
        global: FilterProfile = .default,
        networks: [String: FilterProfile] = [:]
    ) {
        self.global = global
        self.networks = networks
    }

    public static let `default` = FlamewallConfig()
}
