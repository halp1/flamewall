import Foundation

public struct FilterProfile: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var mode: FilterMode
    public var apps: [AppIdentity]

    public init(
        enabled: Bool = false,
        mode: FilterMode = .blacklist,
        apps: [AppIdentity] = []
    ) {
        self.enabled = enabled
        self.mode = mode
        self.apps = apps
    }

    public static let `default` = FilterProfile()
}
