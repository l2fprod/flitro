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
            // Tab selector with improved styling
            Picker(selection: $viewModel.selectedTab) {
                Text("Browse").tag(AddDocumentDialogViewModel.Tab.browse)
                Text("Opened").tag(AddDocumentDialogViewModel.Tab.opened)
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
                } else if viewModel.selectedTab == .opened {
                    openedTabContent
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
                        
                        TextField("e.g., com.apple.TextEdit", text: $viewModel.docApp)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var openedTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    Text("No opened documents detected")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("This feature will detect documents that are currently open in supported applications.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 40)
            
            Spacer()
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