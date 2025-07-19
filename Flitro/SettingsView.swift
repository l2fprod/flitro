import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("startAtLogin") private var startAtLogin: Bool = false

    var body: some View {
        Form {
            Toggle(isOn: $startAtLogin) {
                Text("Start Flitro at login")
            }
            .onChange(of: startAtLogin) { value in
                setLaunchAtLogin(enabled: value)
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