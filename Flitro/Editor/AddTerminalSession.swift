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
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $viewModel.termTitle)
            HStack {
                TextField("Working Directory", text: $viewModel.workingDirectory)
                Button("Choose...") {
                    viewModel.showDirectoryPicker = true
                }
            }
            HStack {
                TextField("Shell Command or Script Path", text: $viewModel.command)
                Button("Choose...") {
                    viewModel.showScriptPicker = true
                }
            }
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
