import Foundation
import os.log

final class PolicyStore {
    static let shared = PolicyStore()

    private let lock = NSLock()
    private var _policy: EffectivePolicy = .allowAll
    private let log = OSLog(subsystem: FlamewallConstants.filterBundleID, category: "Policy")

    var policy: EffectivePolicy {
        lock.lock()
        defer { lock.unlock() }
        return _policy
    }

    func update(_ policy: EffectivePolicy) {
        lock.lock()
        _policy = policy
        lock.unlock()
        persist(policy)
        os_log("Policy updated enabled=%{public}d mode=%{public}@ apps=%{public}d",
               log: log,
               type: .info,
               policy.filteringEnabled,
               policy.mode.rawValue,
               policy.bundleIDs.count)
    }

    func loadFromDisk() {
        guard let url = cacheURL(),
              let data = try? Data(contentsOf: url),
              let policy = try? JSONDecoder().decode(EffectivePolicy.self, from: data)
        else {
            // Fail-open until host connects
            update(.allowAll)
            return
        }
        lock.lock()
        _policy = policy
        lock.unlock()
    }

    private func persist(_ policy: EffectivePolicy) {
        guard let url = cacheURL() else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(policy)
            try data.write(to: url, options: [.atomic])
        } catch {
            os_log("Failed to persist policy: %{public}@", log: log, type: .error, String(describing: error))
        }
    }

    private func cacheURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FlamewallFilter", isDirectory: true)
            .appendingPathComponent("policy.json")
    }
}
