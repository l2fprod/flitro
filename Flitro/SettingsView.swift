import SwiftUI
import ServiceManagement
import Sparkle

struct SettingsView: View {
    let updater: SPUUpdater
    @AppStorage("startAtLogin") private var startAtLogin: Bool = false
    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool

    init(updater: SPUUpdater) {
        self.updater = updater
        _automaticallyChecksForUpdates = State(wrappedValue: updater.automaticallyChecksForUpdates)
        _automaticallyDownloadsUpdates = State(wrappedValue: updater.automaticallyDownloadsUpdates)
    }

    var body: some View {
        Form {
            Toggle(isOn: $startAtLogin) {
                Text("Start Flitro at login")
            }
            .onChange(of: startAtLogin) { newValue, _ in
                setLaunchAtLogin(enabled: newValue)
            }
            Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                .onChange(of: automaticallyChecksForUpdates) { newValue, _ in
                    updater.automaticallyChecksForUpdates = newValue
                }
            Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                .disabled(!automaticallyChecksForUpdates)
                .onChange(of: automaticallyDownloadsUpdates) { newValue, _ in
                    updater.automaticallyDownloadsUpdates = newValue
                }
        }
        .padding()
        .frame(width: 320)
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Handle error (e.g., show an alert)
        }
    }
}