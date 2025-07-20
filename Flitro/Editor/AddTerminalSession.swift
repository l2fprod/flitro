import SwiftUI

class AddTerminalDialogViewModel: ObservableObject {
    @Published var termTitle: String = ""
    @Published var workingDirectory: String = ""
    @Published var command: String = ""
    @Published var showDirectoryPicker: Bool = false
    @Published var showScriptPicker: Bool = false
    
    func createTerminalSession() -> TerminalSession {
        TerminalSession(workingDirectory: workingDirectory, command: command.isEmpty ? nil : command, title: termTitle)
    }
    
    var isConfirmDisabled: Bool {
        termTitle.isEmpty || workingDirectory.isEmpty
    }
}

struct AddTerminalDialog: View {
    @StateObject private var viewModel = AddTerminalDialogViewModel()
    var onAdd: (TerminalSession) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GenericDialog(
            title: "Add Shell Script",
            icon: "terminal",
            subtitle: "Add a terminal session to your context",
            isConfirmDisabled: viewModel.isConfirmDisabled,
            onCancel: onCancel,
            onConfirm: { _ in
                let term = viewModel.createTerminalSession()
                onAdd(term)
            }
        ) {
            AddTerminalDialogContent(viewModel: viewModel, onAdd: onAdd)
        }
    }
}

struct AddTerminalDialogContent: View {
    @ObservedObject var viewModel: AddTerminalDialogViewModel
    var onAdd: (TerminalSession) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Title input section
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "textformat")
                            .foregroundColor(.accentColor)
                        Text("Session Title")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Give your terminal session a descriptive name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                TextField("e.g., Development Server", text: $viewModel.termTitle)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Working directory section
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.accentColor)
                        Text("Working Directory")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("The directory where the terminal session will start")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    TextField("/path/to/directory", text: $viewModel.workingDirectory)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: { viewModel.showDirectoryPicker = true }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Choose")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: true)
                }
            }
            
            // Command section
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundColor(.accentColor)
                        Text("Command (Optional)")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Shell command or script to run. Leave empty to start an interactive shell.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    TextField("e.g., npm start", text: $viewModel.command)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: { viewModel.showScriptPicker = true }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Choose")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: true)
                }
            }
            
            Spacer()
        }
        .fileImporter(isPresented: $viewModel.showScriptPicker, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            if let url = try? result.get().first {
                viewModel.command = url.path
                if viewModel.workingDirectory.isEmpty {
                    viewModel.workingDirectory = url.deletingLastPathComponent().path
                }
                if viewModel.termTitle.isEmpty {
                    viewModel.termTitle = url.deletingPathExtension().lastPathComponent
                }
            }
        }
        .onChange(of: viewModel.showDirectoryPicker) { _, newValue in
            if newValue {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    viewModel.workingDirectory = url.path
                }
                viewModel.showDirectoryPicker = false
            }
        }
    }
}
