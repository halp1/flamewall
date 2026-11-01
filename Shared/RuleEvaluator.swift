import Foundation

public enum RuleEvaluator {
    /// Returns `true` when the flow should be allowed.
    ///
    /// Unknown / missing bundle IDs: allow on blacklist, deny on whitelist (strict).
    public static func allows(bundleID: String?, policy: EffectivePolicy) -> Bool {
        guard policy.filteringEnabled else { return true }

        switch policy.mode {
        case .whitelist:
            guard let bundleID else { return false }
            // Empty whitelist + enabled = block all
            return policy.bundleIDs.contains(bundleID)
        case .blacklist:
            guard let bundleID else { return true }
            // Empty blacklist + enabled = allow all
            return !policy.bundleIDs.contains(bundleID)
        }
    }
}
