import Foundation

public enum FlamewallXPC {
    public static let machServiceName = "com.flamewall.app.filter.xpc"
}

@objc public protocol FlamewallFilterXPCProtocol {
    func updatePolicy(_ data: Data, reply: @escaping (Bool) -> Void)
    func currentPolicy(reply: @escaping (Data?) -> Void)
}

public enum FlamewallConstants {
    public static let hostBundleID = "com.flamewall.app"
    public static let filterBundleID = "com.flamewall.app.filter"
    public static let appSupportFolderName = "Flamewall"
}
