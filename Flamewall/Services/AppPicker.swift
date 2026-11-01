import AppKit
import Foundation

enum AppPicker {
    struct RunningApp: Identifiable, Hashable {
        var bundleID: String
        var displayName: String
        var id: String { bundleID }
    }

    static func runningApps() -> [RunningApp] {
        let apps = NSWorkspace.shared.runningApplications
        var seen = Set<String>()
        var result: [RunningApp] = []
        for app in apps {
            guard app.activationPolicy == .regular,
                  let bundleID = app.bundleIdentifier,
                  !bundleID.isEmpty,
                  seen.insert(bundleID).inserted
            else { continue }
            let name = app.localizedName ?? bundleID
            result.append(RunningApp(bundleID: bundleID, displayName: name))
        }
        return result.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    @MainActor
    static func chooseApp() -> AppIdentity? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an app to add to the filter list"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier
        else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return AppIdentity(bundleID: bundleID, displayName: name)
    }
}
