import Foundation

public struct AppIdentity: Codable, Hashable, Identifiable, Sendable {
    public var bundleID: String
    public var displayName: String

    public var id: String { bundleID }

    public init(bundleID: String, displayName: String) {
        self.bundleID = bundleID
        self.displayName = displayName
    }
}
