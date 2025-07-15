import SwiftUI

class AddDocumentDialogViewModel: ObservableObject {
    enum Tab { case browse, opened }
    @Published var selectedTab: Tab = .browse
    @Published var docName: String = ""
    @Published var docPath: String = ""
    @Published var docApp: String = ""
    @Published var showOpenPanel = false
    @Published var bookmark: Data? = nil
    
    func createDocumentItem() -> DocumentItem {
        return DocumentItem(name: docName, filePath: docPath, application: docApp.isEmpty ? "" : docApp, bookmark: bookmark)
    }
    
    var isConfirmDisabled: Bool {
        docName.isEmpty || docPath.isEmpty
    }
}

struct AddDocumentDialogContent: View {
    @ObservedObject var viewModel: AddDocumentDialogViewModel
    var onAdd: (DocumentItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Method", selection: $viewModel.selectedTab) {
                Text("Browse").tag(AddDocumentDialogViewModel.Tab.browse)
                Text("Opened Documents").tag(AddDocumentDialogViewModel.Tab.opened)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 16)
            
            if viewModel.selectedTab == .browse {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Choose Document...") {
                        viewModel.showOpenPanel = true
                    }
                    if !viewModel.docPath.isEmpty {
                        Text("Name: \(viewModel.docName)")
                        Text("Path: \(viewModel.docPath)")
                        TextField("Application (optional)", text: $viewModel.docApp)
                    }
                }
            } else if viewModel.selectedTab == .opened {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No opened documents detected.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: viewModel.showOpenPanel) { oldValue, newValue in
            if newValue {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                if panel.runModal() == .OK, let url = panel.url {
                    viewModel.docName = url.deletingPathExtension().lastPathComponent
                    viewModel.docPath = url.path
                    do {
                        viewModel.bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    } catch {
                        viewModel.bookmark = nil
                    }
                }
                viewModel.showOpenPanel = false
            }
        }
    }
}

struct AddDocumentDialog: View {
    @StateObject private var viewModel = AddDocumentDialogViewModel()
    var onAdd: (DocumentItem) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GenericDialog(
            title: "Add Document",
            isConfirmDisabled: viewModel.isConfirmDisabled,
            onCancel: onCancel,
            onConfirm: { _ in
                let docItem = viewModel.createDocumentItem()
                onAdd(docItem)
            }
        ) {
            AddDocumentDialogContent(viewModel: viewModel, onAdd: onAdd)
        }
    }
}