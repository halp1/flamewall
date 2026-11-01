import Foundation

public struct NetworkUsage: Codable, Equatable, Identifiable, Sendable {
    public var ssid: String
    public var bytesIn: UInt64
    public var bytesOut: UInt64

    public var id: String { ssid }

    public init(ssid: String, bytesIn: UInt64 = 0, bytesOut: UInt64 = 0) {
        self.ssid = ssid
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }

    public var totalBytes: UInt64 { bytesIn &+ bytesOut }
}

public struct UsageStore: Codable, Equatable, Sendable {
    public var networks: [String: NetworkUsage]

    public init(networks: [String: NetworkUsage] = [:]) {
        self.networks = networks
    }

    public static let `default` = UsageStore()
}
