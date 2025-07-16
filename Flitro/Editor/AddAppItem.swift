import SwiftUI
import UniformTypeIdentifiers

class AddAppDialogViewModel: ObservableObject {
    enum Tab { case browse, running, manual }
    @Published var selectedTab: Tab = .browse
    @Published var manualName: String = ""
    @Published var manualBundle: String = ""
    @Published var manualWindowTitle: String = ""
    @Published var selectedRunningAppPIDs: Set<pid_t> = []
    @Published var browseAppName: String = ""
    @Published var browseBundle: String = ""
    @Published var browseWindowTitle: String = ""
    @Published var showOpenPanel = false
    
    func createAppItem() -> AppItem? {
        if selectedTab == .browse {
            return AppItem(name: browseAppName, bundleIdentifier: browseBundle, windowTitle: browseWindowTitle.isEmpty ? nil : browseWindowTitle)
        } else if selectedTab == .running {
            let runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.bundleIdentifier != nil && $0.activationPolicy == .regular }
                .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
            let selectedApps = runningApps.filter { selectedRunningAppPIDs.contains($0.processIdentifier) }
            if let app = selectedApps.first, let name = app.localizedName, let bundle = app.bundleIdentifier {
                return AppItem(name: name, bundleIdentifier: bundle, windowTitle: nil)
            }
        } else if selectedTab == .manual {
            return AppItem(name: manualName, bundleIdentifier: manualBundle, windowTitle: manualWindowTitle.isEmpty ? nil : manualWindowTitle)
        }
        return nil
    }
    
    var isConfirmDisabled: Bool {
        (selectedTab == .browse && (browseAppName.isEmpty || browseBundle.isEmpty)) ||
        (selectedTab == .running && selectedRunningAppPIDs.isEmpty) ||
        (selectedTab == .manual && (manualName.isEmpty || manualBundle.isEmpty))
    }
}

struct AddAppDialogContent: View {
    @ObservedObject var viewModel: AddAppDialogViewModel
    var onAdd: (AppItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker(selection: $viewModel.selectedTab) {
                Text("Browse").tag(AddAppDialogViewModel.Tab.browse)
                Text("Running Apps").tag(AddAppDialogViewModel.Tab.running)
                Text("Manual").tag(AddAppDialogViewModel.Tab.manual)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 16)
            
            if viewModel.selectedTab == .browse {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Choose Application...") {
                        viewModel.showOpenPanel = true
                    }
                    if !viewModel.browseAppName.isEmpty {
                        Text("Name: \(viewModel.browseAppName)")
                        Text("Bundle ID: \(viewModel.browseBundle)")
                        TextField("Window Title (optional)", text: $viewModel.browseWindowTitle)
                    }
                }
            } else if viewModel.selectedTab == .running {
                let runningApps = NSWorkspace.shared.runningApplications
                    .filter { $0.bundleIdentifier != nil && $0.activationPolicy == .regular }
                    .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
                List(runningApps, id: \.processIdentifier) { app in
                    HStack {
                        Text(app.localizedName ?? "Unknown")
                        Spacer()
                        Text(app.bundleIdentifier ?? "")
                        if viewModel.selectedRunningAppPIDs.contains(app.processIdentifier) {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.selectedRunningAppPIDs.contains(app.processIdentifier) {
                            viewModel.selectedRunningAppPIDs.remove(app.processIdentifier)
                        } else {
                            viewModel.selectedRunningAppPIDs.insert(app.processIdentifier)
                        }
                    }
                }
            } else if viewModel.selectedTab == .manual {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("App Name", text: $viewModel.manualName)
                    TextField("Bundle Identifier", text: $viewModel.manualBundle)
                    TextField("Window Title (optional)", text: $viewModel.manualWindowTitle)
                }
            }
        }
        .onChange(of: viewModel.showOpenPanel) { oldValue, newValue in
            if newValue {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [UTType.application]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                if panel.runModal() == .OK, let url = panel.url {
                    if let bundle = Bundle(url: url),
                       let bundleId = bundle.bundleIdentifier {
                        viewModel.browseAppName = url.deletingPathExtension().lastPathComponent
                        viewModel.browseBundle = bundleId
                    } else {
                        viewModel.browseAppName = url.deletingPathExtension().lastPathComponent
                        viewModel.browseBundle = ""
                    }
                }
                viewModel.showOpenPanel = false
            }
        }
    }
}

struct AddAppDialog: View {
    @StateObject private var viewModel = AddAppDialogViewModel()
    var onAdd: (AppItem) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GenericDialog(
            title: "Add Application",
            isConfirmDisabled: viewModel.isConfirmDisabled,
            onCancel: onCancel,
            onConfirm: { _ in
                if let appItem = viewModel.createAppItem() {
                    onAdd(appItem)
                }
            }
        ) {
            AddAppDialogContent(viewModel: viewModel, onAdd: onAdd)
        }
    }
}
