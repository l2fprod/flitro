import SwiftUI
import UniformTypeIdentifiers

class AddDocumentDialogViewModel: ObservableObject {
    @Published var docName: String = ""
    @Published var docPath: String = ""
    @Published var docApp: String = ""
    @Published var docAppName: String = ""
    @Published var showOpenPanel = false
    @Published var showAppOpenPanel = false
    @Published var bookmark: Data? = nil
    
    init(initialDocument: DocumentItem? = nil) {
        if let doc = initialDocument {
            self.docName = doc.name
            self.docPath = doc.filePath
            self.docApp = doc.application
            if !doc.application.isEmpty,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: doc.application),
               let bundle = Bundle(url: appURL) {
                self.docAppName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? appURL.deletingPathExtension().lastPathComponent
            } else {
                self.docAppName = ""
            }
            self.bookmark = doc.bookmark
        }
    }
    
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
            browseTabContent
        }
        .onChange(of: viewModel.showOpenPanel) { _, newValue in
            if newValue {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        DispatchQueue.main.async {
                            viewModel.docName = url.deletingPathExtension().lastPathComponent
                            viewModel.docPath = url.path
                            do {
                                viewModel.bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                            } catch {
                                viewModel.bookmark = nil
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        viewModel.showOpenPanel = false
                    }
                }
            }
        }
        .onChange(of: viewModel.showAppOpenPanel) { _, newValue in
            if newValue {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = [UTType.application]
                panel.message = "Select the application to open the document"
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                            DispatchQueue.main.async {
                                viewModel.docApp = bundleId
                                viewModel.docAppName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        viewModel.showAppOpenPanel = false
                    }
                }
            }
        }
    }
    
    private var browseTabContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // File picker button
            Button(action: { viewModel.showOpenPanel = true }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                    Text("Choose Document...")
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
            
            // Document details if selected
            if !viewModel.docPath.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    // Document info card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.accentColor)
                            Text("Selected Document")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Name", value: viewModel.docName)
                            InfoRow(label: "Path", value: viewModel.docPath)
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
                    
                    // Optional application
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Application (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button(action: {
                                viewModel.showAppOpenPanel = true
                            }) {
                                HStack {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.title3)
                                    Text(viewModel.docApp.isEmpty ? "Choose Application..." : viewModel.docAppName)
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

                            if !viewModel.docApp.isEmpty {
                                Button(action: {
                                    viewModel.docApp = ""
                                    viewModel.docAppName = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .help("Clear selected application")
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
}

struct AddDocumentDialog: View {
    @StateObject private var viewModel: AddDocumentDialogViewModel
    var onAdd: (DocumentItem) -> Void
    var onCancel: () -> Void
    
    init(initialDocument: DocumentItem? = nil, onAdd: @escaping (DocumentItem) -> Void, onCancel: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AddDocumentDialogViewModel(initialDocument: initialDocument))
        self.onAdd = onAdd
        self.onCancel = onCancel
    }
    
    var body: some View {
        GenericDialog(
            title: "Add Document",
            icon: "doc.text",
            subtitle: "Add a document or file to your context",
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