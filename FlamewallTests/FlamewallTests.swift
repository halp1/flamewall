import XCTest

final class RuleEvaluatorTests: XCTestCase {
    func testFilteringOffAllowsEverything() {
        let policy = EffectivePolicy(filteringEnabled: false, mode: .whitelist, bundleIDs: [])
        XCTAssertTrue(RuleEvaluator.allows(bundleID: "com.a", policy: policy))
        XCTAssertTrue(RuleEvaluator.allows(bundleID: nil, policy: policy))
    }

    func testEmptyWhitelistBlocksAll() {
        let policy = EffectivePolicy(filteringEnabled: true, mode: .whitelist, bundleIDs: [])
        XCTAssertFalse(RuleEvaluator.allows(bundleID: "com.a", policy: policy))
        XCTAssertFalse(RuleEvaluator.allows(bundleID: nil, policy: policy))
    }

    func testWhitelistAllowsListedOnly() {
        let policy = EffectivePolicy(filteringEnabled: true, mode: .whitelist, bundleIDs: ["com.ok"])
        XCTAssertTrue(RuleEvaluator.allows(bundleID: "com.ok", policy: policy))
        XCTAssertFalse(RuleEvaluator.allows(bundleID: "com.no", policy: policy))
        XCTAssertFalse(RuleEvaluator.allows(bundleID: nil, policy: policy))
    }

    func testEmptyBlacklistAllowsAll() {
        let policy = EffectivePolicy(filteringEnabled: true, mode: .blacklist, bundleIDs: [])
        XCTAssertTrue(RuleEvaluator.allows(bundleID: "com.a", policy: policy))
        XCTAssertTrue(RuleEvaluator.allows(bundleID: nil, policy: policy))
    }

    func testBlacklistBlocksListed() {
        let policy = EffectivePolicy(filteringEnabled: true, mode: .blacklist, bundleIDs: ["com.bad"])
        XCTAssertFalse(RuleEvaluator.allows(bundleID: "com.bad", policy: policy))
        XCTAssertTrue(RuleEvaluator.allows(bundleID: "com.ok", policy: policy))
        XCTAssertTrue(RuleEvaluator.allows(bundleID: nil, policy: policy))
    }
}

final class ProfileResolverTests: XCTestCase {
    func testFallsBackToGlobal() {
        var config = FlamewallConfig()
        config.global = FilterProfile(enabled: true, mode: .blacklist, apps: [])
        let (profile, source) = ProfileResolver.resolve(config: config, ssid: "Home")
        XCTAssertEqual(source, .global)
        XCTAssertTrue(profile.enabled)
    }

    func testNetworkOverridesGlobal() {
        var config = FlamewallConfig()
        config.global = FilterProfile(enabled: false, mode: .blacklist, apps: [])
        config.networks["Cafe"] = FilterProfile(enabled: true, mode: .whitelist, apps: [
            AppIdentity(bundleID: "com.mail", displayName: "Mail")
        ])
        let (profile, source) = ProfileResolver.resolve(config: config, ssid: "Cafe")
        XCTAssertEqual(source, .network("Cafe"))
        XCTAssertTrue(profile.enabled)
        XCTAssertEqual(profile.mode, .whitelist)
        XCTAssertEqual(profile.apps.count, 1)
    }

    func testNilSSIDUsesGlobal() {
        var config = FlamewallConfig()
        config.networks["Cafe"] = FilterProfile(enabled: true, mode: .whitelist, apps: [])
        let (_, source) = ProfileResolver.resolve(config: config, ssid: nil)
        XCTAssertEqual(source, .global)
    }

    func testEffectivePolicyMapping() {
        var config = FlamewallConfig()
        config.global = FilterProfile(
            enabled: true,
            mode: .blacklist,
            apps: [AppIdentity(bundleID: "com.x", displayName: "X")]
        )
        let policy = ProfileResolver.effectivePolicy(config: config, ssid: nil)
        XCTAssertTrue(policy.filteringEnabled)
        XCTAssertEqual(policy.mode, .blacklist)
        XCTAssertEqual(policy.bundleIDs, ["com.x"])
    }
}
