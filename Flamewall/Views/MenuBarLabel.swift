import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject private var usageTracker: UsageTracker
    @EnvironmentObject private var networkMonitor: NetworkMonitor

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            if networkMonitor.currentSSID != nil {
                Text("↓\(ByteFormat.rate(usageTracker.bytesInPerSecond)) ↑\(ByteFormat.rate(usageTracker.bytesOutPerSecond))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}
