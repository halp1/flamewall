import Foundation

public enum FilterMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case whitelist
    case blacklist

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .whitelist: return "Whitelist"
        case .blacklist: return "Blacklist"
        }
    }
}
