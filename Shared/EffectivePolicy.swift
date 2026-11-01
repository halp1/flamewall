import Foundation

public struct EffectivePolicy: Codable, Equatable, Sendable {
    public var filteringEnabled: Bool
    public var mode: FilterMode
    public var bundleIDs: Set<String>

    public init(
        filteringEnabled: Bool = false,
        mode: FilterMode = .blacklist,
        bundleIDs: Set<String> = []
    ) {
        self.filteringEnabled = filteringEnabled
        self.mode = mode
        self.bundleIDs = bundleIDs
    }

    public static let allowAll = EffectivePolicy(
        filteringEnabled: false,
        mode: .blacklist,
        bundleIDs: []
    )

    public static func from(profile: FilterProfile) -> EffectivePolicy {
        EffectivePolicy(
            filteringEnabled: profile.enabled,
            mode: profile.mode,
            bundleIDs: Set(profile.apps.map(\.bundleID))
        )
    }
}
