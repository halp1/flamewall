import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: FlamewallStore
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var usageTracker: UsageTracker
    @EnvironmentObject private var filterController: FilterController
    @EnvironmentObject private var loginItem: LoginItemService

    @State private var selectedTab: SettingsTab = .filter
    @State private var showAppPicker = false
    @State private var editingNetworkSSID: String?
    @State private var newNetworkSSID = ""

    enum SettingsTab: String, CaseIterable, Identifiable {
        case usage, filter, networks, system
        var id: String { rawValue }
        var title: String {
            switch self {
            case .usage: return "Usage"
            case .filter: return "Filter"
            case .networks: return "Networks"
            case .system: return "System"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Flamewall")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                Text(networkMonitor.currentSSID.map { "Wi‑Fi: \($0)" } ?? "Wi‑Fi: Not connected")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            Divider().padding(.top, 12)

            Group {
                switch selectedTab {
                case .usage:
                    usagePane
                case .filter:
                    filterPane
                case .networks:
                    networksPane
                case .system:
                    systemPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showAppPicker) {
            RunningAppsPickerSheet { app in
                if let ssid = editingNetworkSSID {
                    store.addApp(app, to: .network(ssid))
                } else {
                    model.addApp(app)
                }
                model.pushPolicy()
            }
        }
        .onAppear {
            model.start()
        }
    }

    private var usagePane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("Live")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 24) {
                    metric(title: "Download", value: ByteFormat.rate(usageTracker.bytesInPerSecond))
                    metric(title: "Upload", value: ByteFormat.rate(usageTracker.bytesOutPerSecond))
                }
            }

            Group {
                Text("Totals by network")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                if store.usage.networks.isEmpty {
                    Text("No usage recorded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.usage.networks.values.sorted(by: { $0.ssid < $1.ssid })) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.ssid)
                                    .font(.system(size: 13, weight: .medium))
                                Text("↓ \(ByteFormat.total(record.bytesIn))   ↑ \(ByteFormat.total(record.bytesOut))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Spacer()
                            Button("Reset") {
                                store.resetUsage(for: record.ssid)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var filterPane: some View {
        let resolution = model.activeResolution
        return VStack(alignment: .leading, spacing: 16) {
            Text("Active profile: \(resolution.source.displayName)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Toggle("Enable filtering", isOn: Binding(
                get: { resolution.profile.enabled },
                set: { model.toggleFilterEnabled($0) }
            ))
            .toggleStyle(.switch)

            Picker("Mode", selection: Binding(
                get: { resolution.profile.mode },
                set: { model.setMode($0) }
            )) {
                ForEach(FilterMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            HStack {
                Text(resolution.profile.mode == .whitelist ? "Allowed apps" : "Blocked apps")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    editingNetworkSSID = nil
                    showAppPicker = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }

            if resolution.profile.apps.isEmpty {
                Text(resolution.profile.mode == .whitelist
                      ? "Empty whitelist blocks all apps when filtering is on."
                      : "No apps on the list — all traffic allowed when filtering is on.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(resolution.profile.apps) { app in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(app.displayName)
                            Text(app.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Remove") {
                            model.removeApp(bundleID: app.bundleID)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }

            Text("Editing the active profile. Global is used unless this Wi‑Fi network has its own override.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private var networksPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Per-network overrides")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("When connected to a listed network, that profile replaces Global.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack {
                TextField("SSID", text: $newNetworkSSID)
                    .textFieldStyle(.roundedBorder)
                Button("Add current") {
                    if let ssid = networkMonitor.currentSSID {
                        store.setNetworkProfile(ssid: ssid, profile: store.config.global)
                        model.pushPolicy()
                    }
                }
                .disabled(networkMonitor.currentSSID == nil)

                Button("Add") {
                    let ssid = newNetworkSSID.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !ssid.isEmpty else { return }
                    store.setNetworkProfile(ssid: ssid, profile: FilterProfile())
                    newNetworkSSID = ""
                    model.pushPolicy()
                }
                .disabled(newNetworkSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if store.config.networks.isEmpty {
                Text("No per-network profiles yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.config.networks.keys.sorted(), id: \.self) { ssid in
                    networkRow(ssid: ssid)
                }
            }

            Group {
                Text("Global profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                globalEditor
            }
        }
    }

    private func networkRow(ssid: String) -> some View {
        let profile = store.config.networks[ssid] ?? .default
        let isCurrent = networkMonitor.currentSSID == ssid
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ssid)
                    .font(.system(size: 13, weight: .medium))
                if isCurrent {
                    Text("Current")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .separatorColor).opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                Button("Delete") {
                    store.setNetworkProfile(ssid: ssid, profile: nil)
                    model.pushPolicy()
                }
                .buttonStyle(.borderless)
            }

            Toggle("Enabled", isOn: Binding(
                get: { store.config.networks[ssid]?.enabled ?? false },
                set: { enabled in
                    var p = store.config.networks[ssid] ?? FilterProfile()
                    p.enabled = enabled
                    store.setNetworkProfile(ssid: ssid, profile: p)
                    model.pushPolicy()
                }
            ))

            Picker("Mode", selection: Binding(
                get: { store.config.networks[ssid]?.mode ?? .blacklist },
                set: { mode in
                    var p = store.config.networks[ssid] ?? FilterProfile()
                    p.mode = mode
                    store.setNetworkProfile(ssid: ssid, profile: p)
                    model.pushPolicy()
                }
            )) {
                ForEach(FilterMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)

            HStack {
                Text("\(profile.apps.count) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add app") {
                    editingNetworkSSID = ssid
                    showAppPicker = true
                }
                .buttonStyle(.borderless)
            }

            ForEach(profile.apps) { app in
                HStack {
                    Text(app.displayName)
                        .font(.system(size: 12))
                    Spacer()
                    Button {
                        store.removeApp(bundleID: app.bundleID, from: .network(ssid))
                        model.pushPolicy()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var globalEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enabled", isOn: Binding(
                get: { store.config.global.enabled },
                set: { enabled in
                    var p = store.config.global
                    p.enabled = enabled
                    store.setGlobal(p)
                    model.pushPolicy()
                }
            ))
            Picker("Mode", selection: Binding(
                get: { store.config.global.mode },
                set: { mode in
                    var p = store.config.global
                    p.mode = mode
                    store.setGlobal(p)
                    model.pushPolicy()
                }
            )) {
                ForEach(FilterMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var systemPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("Network extension")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Status: \(filterController.status.displayName)")
                    .font(.system(size: 13))
                Text(filterController.filterConfigurationEnabled ? "Filter configuration: On" : "Filter configuration: Off")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Activate Filter") {
                        filterController.activateExtension()
                    }
                    Button("Enable Configuration") {
                        Task { await filterController.enableFilterConfiguration() }
                    }
                    Button("Disable Configuration") {
                        Task { await filterController.disableFilterConfiguration() }
                    }
                }

                Text("Requires `systemextensionsctl developer on`. Approve the extension in System Settings when prompted, then enable the filter configuration. Leave Filter off until your lists look right — default is Off with an empty blacklist (allow all).")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Group {
                Text("Launch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Toggle("Start at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if let error = loginItem.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Divider()

            Text("Flamewall 1.0")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }
}
