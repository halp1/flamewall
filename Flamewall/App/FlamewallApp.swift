import AppKit
import SwiftUI

@main
struct FlamewallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
                .environmentObject(model.store)
                .environmentObject(model.networkMonitor)
                .environmentObject(model.usageTracker)
                .environmentObject(model.filterController)
                .environmentObject(model.loginItem)
        } label: {
            MenuBarLabel()
                .environmentObject(model.usageTracker)
                .environmentObject(model.networkMonitor)
        }
        .menuBarExtraStyle(.window)

        Window("Flamewall Settings", id: "settings") {
            SettingsView()
                .environmentObject(model)
                .environmentObject(model.store)
                .environmentObject(model.networkMonitor)
                .environmentObject(model.usageTracker)
                .environmentObject(model.filterController)
                .environmentObject(model.loginItem)
                .frame(minWidth: 520, minHeight: 480)
        }
        .defaultSize(width: 560, height: 560)
    }

    init() {
        // Wire model into app delegate after StateObject init via onAppear in MenuBarView,
        // and also here through a deferred assignment in the adaptor once scenes load.
    }
}
