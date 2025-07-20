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
            // Tab selector with improved styling
            Picker(selection: $viewModel.selectedTab) {
                Text("Browse").tag(AddAppDialogViewModel.Tab.browse)
                Text("Running").tag(AddAppDialogViewModel.Tab.running)
                Text("Manual").tag(AddAppDialogViewModel.Tab.manual)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 24)
            
            // Content based on selected tab
            Group {
                if viewModel.selectedTab == .browse {
                    browseTabContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else if viewModel.selectedTab == .running {
                    runningTabContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else if viewModel.selectedTab == .manual {
                    manualTabContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.selectedTab)
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
    
    private var browseTabContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // File picker button
            Button(action: { viewModel.showOpenPanel = true }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                        .font(.title3)
                    Text("Choose Application...")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.1), value: true)
            
            // App details if selected
            if !viewModel.browseAppName.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    // App info card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "app.badge")
                                .foregroundColor(.accentColor)
                            Text("Selected Application")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Name", value: viewModel.browseAppName)
                            InfoRow(label: "Bundle ID", value: viewModel.browseBundle)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    // Optional window title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Window Title (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("e.g., Untitled Document", text: $viewModel.browseWindowTitle)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var runningTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select from currently running applications:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            let runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.bundleIdentifier != nil && $0.activationPolicy == .regular }
                .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
            
            if runningApps.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("No running applications found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(runningApps, id: \.processIdentifier) { app in
                            RunningAppRow(
                                app: app,
                                isSelected: viewModel.selectedRunningAppPIDs.contains(app.processIdentifier),
                                onToggle: {
                                    if viewModel.selectedRunningAppPIDs.contains(app.processIdentifier) {
                                        viewModel.selectedRunningAppPIDs.remove(app.processIdentifier)
                                    } else {
                                        viewModel.selectedRunningAppPIDs.insert(app.processIdentifier)
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
            
            Spacer()
        }
    }
    
    private var manualTabContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                InputField(
                    label: "Application Name",
                    placeholder: "e.g., My Custom App",
                    text: $viewModel.manualName
                )
                
                InputField(
                    label: "Bundle Identifier",
                    placeholder: "com.example.myapp",
                    text: $viewModel.manualBundle
                )
                
                InputField(
                    label: "Window Title (Optional)",
                    placeholder: "e.g., Untitled Document",
                    text: $viewModel.manualWindowTitle
                )
            }
            
            Spacer()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

struct RunningAppRow: View {
    let app: NSRunningApplication
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // App icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "app.badge")
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                
                // App info
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.localizedName ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(app.bundleIdentifier ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct InputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
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
            icon: "app.badge",
            subtitle: "Add an application to your context",
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
