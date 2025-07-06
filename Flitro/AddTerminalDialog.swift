import SwiftUI
import AppKit

struct AddTerminalDialog: View {
    @State private var title: String = ""
    @State private var workingDirectory: String = ""
    @State private var command: String = ""
    @State private var showDirectoryPicker = false
    @State private var showScriptPicker = false
    var onAdd: (TerminalSession) -> Void
    var onCancel: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Terminal Session")
                .font(.title2).fontWeight(.bold)
                .padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 12) {
                TextField("Title", text: $title)
                HStack {
                    TextField("Working Directory", text: $workingDirectory)
                    Button("Choose...") {
                        showDirectoryPicker = true
                    }
                }
                HStack {
                    TextField("Shell Command or Script Path", text: $command)
                    Button("Choose...") {
                        showScriptPicker = true
                    }
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Add") {
                    let session = TerminalSession(workingDirectory: workingDirectory, command: command, title: title.isEmpty ? (command.isEmpty ? "Terminal" : command) : title)
                    onAdd(session)
                }
                .disabled(command.isEmpty || workingDirectory.isEmpty)
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(width: 420, height: 220)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
        .fileImporter(isPresented: $showScriptPicker, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            if let url = try? result.get().first {
                command = url.path
                if workingDirectory.isEmpty {
                    workingDirectory = url.deletingLastPathComponent().path
                }
                if title.isEmpty {
                    title = url.deletingPathExtension().lastPathComponent
                }
            }
        }
        .onChange(of: showDirectoryPicker) { _, newValue in
            if newValue {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    workingDirectory = url.path
                }
                showDirectoryPicker = false
            }
        }
    }
} 