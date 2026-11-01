import SwiftUI

struct RunningAppsPickerSheet: View {
    var onSelect: (AppIdentity) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var apps: [AppPicker.RunningApp] = []
    @State private var query = ""

    private var filtered: [AppPicker.RunningApp] {
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.bundleID.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add App")
                .font(.headline)
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)

            List(filtered) { app in
                Button {
                    onSelect(AppIdentity(bundleID: app.bundleID, displayName: app.displayName))
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.displayName)
                        Text(app.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 240)

            HStack {
                Button("Choose…") {
                    if let app = AppPicker.chooseApp() {
                        onSelect(app)
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 360, height: 400)
        .onAppear {
            apps = AppPicker.runningApps()
        }
    }
}
