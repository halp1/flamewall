import Darwin
import Foundation

enum InterfaceCounters {
    struct Snapshot: Equatable {
        var bytesIn: UInt64
        var bytesOut: UInt64
    }

    /// Reads cumulative interface byte counters via getifaddrs.
    static func snapshot(for interfaceName: String) -> Snapshot? {
        var raw: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&raw) == 0, let first = raw else { return nil }
        defer { freeifaddrs(raw) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let addr = cursor {
            defer { cursor = addr.pointee.ifa_next }
            guard let name = addr.pointee.ifa_name else { continue }
            let ifName = String(cString: name)
            guard ifName == interfaceName else { continue }
            guard let data = addr.pointee.ifa_data else { continue }
            let ifdata = data.assumingMemoryBound(to: if_data.self)
            return Snapshot(
                bytesIn: UInt64(ifdata.pointee.ifi_ibytes),
                bytesOut: UInt64(ifdata.pointee.ifi_obytes)
            )
        }
        return nil
    }
}
