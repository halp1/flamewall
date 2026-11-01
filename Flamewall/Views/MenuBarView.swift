import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: FlamewallStore
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var usageTracker: UsageTracker
    @Environment(\.openWindow) private var openWindow

    @State private var showAppPicker = false

    private var resolution: (profile: FilterProfile, source: ProfileSource) {
        model.activeResolution
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 8)
            usageSection
            Divider().padding(.vertical, 8)
            filterSection
            Divider().padding(.vertical, 8)
            appsSection
            Divider().padding(.vertical, 8)
            footer
        }
        .padding(14)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            model.start()
            // Keep AppDelegate in sync for terminate flush / activation policy
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.model = model
            }
        }
        .onChange(of: networkMonitor.currentSSID) { _, _ in
            model.pushPolicy()
        }
        .sheet(isPresented: $showAppPicker) {
            RunningAppsPickerSheet { app in
                model.addApp(app)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Flamewall")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .labelColor))
                Text(networkMonitor.currentSSID ?? "Not connected")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .foregroundStyle(Color(red: 0.22, green: 0.22, blue: 0.24))
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text("↓ \(ByteFormat.rate(usageTracker.bytesInPerSecond))")
                } icon: {
                    EmptyView()
                }
                Spacer()
                Text("↑ \(ByteFormat.rate(usageTracker.bytesOutPerSecond))")
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .monospacedDigit()

            HStack {
                let total = store.usage(for: networkMonitor.currentSSID)
                Text("Total \(ByteFormat.total(total?.totalBytes ?? 0))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset") {
                    usageTracker.resetCurrentNetwork()
                }
                .buttonStyle(.borderless)
                .disabled(networkMonitor.currentSSID == nil)
                .font(.system(size: 12, weight: .medium))
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Filter", isOn: Binding(
                get: { resolution.profile.enabled },
                set: { model.toggleFilterEnabled($0) }
            ))
            .toggleStyle(.switch)
            .font(.system(size: 13, weight: .medium))

            HStack {
                Text(resolution.source.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Mode", selection: Binding(
                    get: { resolution.profile.mode },
                    set: { model.setMode($0) }
                )) {
                    ForEach(FilterMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(resolution.profile.mode == .whitelist ? "Allowed apps" : "Blocked apps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showAppPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add app")
            }

            if resolution.profile.apps.isEmpty {
                Text(resolution.profile.mode == .whitelist
                      ? "Empty whitelist blocks all traffic when filter is on"
                      : "No apps blocked")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(resolution.profile.apps) { app in
                    HStack {
                        Text(app.displayName)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            model.removeApp(bundleID: app.bundleID)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .frame(maxHeight: 140)
    }

    private var footer: some View {
        HStack {
            Button("Settings…") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12, weight: .medium))

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12, weight: .medium))
        }
    }
}
