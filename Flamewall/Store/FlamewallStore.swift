import Foundation

@MainActor
final class FlamewallStore: ObservableObject {
    @Published private(set) var config: FlamewallConfig
    @Published private(set) var usage: UsageStore

    private let fileManager: FileManager
    private let configURL: URL
    private let usageURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let support = Self.applicationSupportDirectory(fileManager: fileManager)
        self.configURL = support.appendingPathComponent("config.json")
        self.usageURL = support.appendingPathComponent("usage.json")
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()

        self.config = Self.load(FlamewallConfig.self, from: configURL, default: .default, decoder: decoder) ?? .default
        self.usage = Self.load(UsageStore.self, from: usageURL, default: .default, decoder: decoder) ?? .default
    }

    func updateConfig(_ mutate: (inout FlamewallConfig) -> Void) {
        var next = config
        mutate(&next)
        config = next
        saveConfig()
    }

    func setGlobal(_ profile: FilterProfile) {
        updateConfig { $0.global = profile }
    }

    func setNetworkProfile(ssid: String, profile: FilterProfile?) {
        updateConfig { config in
            if let profile {
                config.networks[ssid] = profile
            } else {
                config.networks.removeValue(forKey: ssid)
            }
        }
    }

    func addApp(_ app: AppIdentity, to source: ProfileSource) {
        updateConfig { config in
            switch source {
            case .global:
                if !config.global.apps.contains(where: { $0.bundleID == app.bundleID }) {
                    config.global.apps.append(app)
                }
            case .network(let ssid):
                var profile = config.networks[ssid] ?? FilterProfile()
                if !profile.apps.contains(where: { $0.bundleID == app.bundleID }) {
                    profile.apps.append(app)
                }
                config.networks[ssid] = profile
            }
        }
    }

    func removeApp(bundleID: String, from source: ProfileSource) {
        updateConfig { config in
            switch source {
            case .global:
                config.global.apps.removeAll { $0.bundleID == bundleID }
            case .network(let ssid):
                config.networks[ssid]?.apps.removeAll { $0.bundleID == bundleID }
            }
        }
    }

    func resetUsage(for ssid: String) {
        var next = usage
        next.networks[ssid] = NetworkUsage(ssid: ssid, bytesIn: 0, bytesOut: 0)
        usage = next
        saveUsage()
    }

    func accumulateUsage(ssid: String, deltaIn: UInt64, deltaOut: UInt64, persist: Bool = true) {
        guard deltaIn > 0 || deltaOut > 0 else { return }
        var next = usage
        var record = next.networks[ssid] ?? NetworkUsage(ssid: ssid)
        record.bytesIn &+= deltaIn
        record.bytesOut &+= deltaOut
        next.networks[ssid] = record
        usage = next
        if persist {
            saveUsage()
        }
    }

    func flush() {
        saveConfig()
        saveUsage()
    }

    func usage(for ssid: String?) -> NetworkUsage? {
        guard let ssid else { return nil }
        return usage.networks[ssid]
    }

    private func saveConfig() {
        save(config, to: configURL)
    }

    private func saveUsage() {
        save(usage, to: usageURL)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            NSLog("FlamewallStore save failed: \(error)")
        }
    }

    private static func load<T: Decodable>(
        _ type: T.Type,
        from url: URL,
        default defaultValue: T,
        decoder: JSONDecoder
    ) -> T? {
        guard fileExists(url) else { return defaultValue }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            NSLog("FlamewallStore load failed: \(error)")
            return defaultValue
        }
    }

    private static func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(FlamewallConstants.appSupportFolderName, isDirectory: true)
    }
}
