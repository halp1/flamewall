import Foundation

enum ByteFormat {
    static func rate(_ bytesPerSecond: Double) -> String {
        let abs = Swift.abs(bytesPerSecond)
        if abs < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if abs < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else if abs < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        } else {
            return String(format: "%.2f GB/s", bytesPerSecond / (1024 * 1024 * 1024))
        }
    }

    static func total(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if value < 1024 {
            return String(format: "%.0f B", value)
        } else if value < 1024 * 1024 {
            return String(format: "%.1f KB", value / 1024)
        } else if value < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", value / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", value / (1024 * 1024 * 1024))
        }
    }
}
