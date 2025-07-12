import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit
import PhosphorSwift

// MARK: - Context Editor View

struct ContextEditorView: View {
    @ObservedObject var contextManager: ContextManager
    @Binding var selectedContextID: UUID?
    @State private var showDeleteAlert = false
    @State private var showAddAppDialog = false
    @State private var showAddDocumentDialog = false
    @State private var showAddBrowserTabDialog = false
    @State private var showAddTerminalDialog = false
    
    var selectedContext: Context? {
        contextManager.contexts.first(where: { $0.id == selectedContextID })
    }
    
    var body: some View {
        NavigationSplitView {
            ContextSidebarView(
                contextManager: contextManager,
                selectedContextID: $selectedContextID,
                showDeleteAlert: $showDeleteAlert
            )
        } detail: {
            ContextDetailsView(
                contextManager: contextManager,
                selectedContextID: $selectedContextID,
                showAddAppDialog: $showAddAppDialog,
                showAddDocumentDialog: $showAddDocumentDialog,
                showAddBrowserTabDialog: $showAddBrowserTabDialog,
                showAddTerminalDialog: $showAddTerminalDialog
            )
            .onDrop(of: [UTType.fileURL, UTType.url, UTType.text, UTType.plainText], isTargeted: nil) { providers in
                return handleUniversalDrop(providers: providers)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleUniversalDrop(providers: [NSItemProvider]) -> Bool {
        guard let contextIndex = contextManager.contexts.firstIndex(where: { $0.id == selectedContextID }) else { 
            print("No selected context found for drop")
            return false 
        }
        
        guard !providers.isEmpty else {
            print("No providers in drop")
            return false
        }
        
        var handled = false
        
        for provider in providers {
            print("Processing provider with types: \(provider.registeredTypeIdentifiers)")
            
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) || provider.hasItemConformingToTypeIdentifier("public.file-url") {
                let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ? UTType.fileURL.identifier : "public.file-url"
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                    if let error = error {
                        print("Error loading file URL: \(error)")
                        return
                    }
                    print("Loaded item: \(String(describing: item))")
                    
                    var url: URL?
                    if let urlObject = item as? URL {
                        url = urlObject
                    } else if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                        print("Converted data to URL: \(String(describing: url))")
                    }
                    
                    if let url = url {
                        print("Processing URL: \(url)")
                        DispatchQueue.main.async {
                            if url.pathExtension == "app" {
                                // Add as application
                                if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                                    let appItem = AppItem(name: url.deletingPathExtension().lastPathComponent, bundleIdentifier: bundleId, windowTitle: nil)
                                    contextManager.contexts[contextIndex].applications.append(appItem)
                                    contextManager.saveContexts()
                                    print("Added application: \(appItem.name)")
                                }
                            } else {
                                // Add as document
                                var bookmark: Data? = nil
                                do {
                                    bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                                } catch {
                                    bookmark = nil
                                }
                                let document = DocumentItem(
                                    name: url.deletingPathExtension().lastPathComponent,
                                    filePath: url.path,
                                    application: "",
                                    bookmark: bookmark
                                )
                                contextManager.contexts[contextIndex].documents.append(document)
                                contextManager.saveContexts()
                                print("Added document: \(document.name)")
                            }
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                        DispatchQueue.main.async {
                            contextManager.contexts[contextIndex].browserTabs.append(browserTab)
                            contextManager.saveContexts()
                        }
                    } else if let url = item as? URL {
                        let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                        DispatchQueue.main.async {
                            contextManager.contexts[contextIndex].browserTabs.append(browserTab)
                            contextManager.saveContexts()
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) ? UTType.text.identifier : UTType.plainText.identifier
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                    if let text = item as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Try to parse as URL first
                        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                            DispatchQueue.main.async {
                                contextManager.contexts[contextIndex].browserTabs.append(browserTab)
                                contextManager.saveContexts()
                                print("Added browser tab: \(browserTab.title)")
                            }
                        }
                    }
                }
                handled = true
            }
        }
        
        print("Drop handling complete. Handled: \(handled)")
        return handled
    }
}

// MARK: - UI Components

struct CardSection: View {
    var title: String
    var items: [CardRow]
    var onAdd: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 18)
            HStack {
                Text(title)
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                if let onAdd = onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            VStack(spacing: 0) {
                if items.isEmpty {
                    HStack {
                        Spacer()
                        Text("No items")
                            .foregroundColor(.secondary)
                            .font(.body)
                        Spacer()
                    }
                    .frame(minHeight: 56)
                } else {
                    ForEach(items.indices, id: \.self) { idx in
                        items[idx]
                        if idx < items.count - 1 {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.vertical, 4)
    }
}

struct CardRow: View {
    var icon: String
    var title: String
    var subtitle: String?
    var onOpen: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                if let subtitle = subtitle {
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if let onOpen = onOpen {
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.plain)
                .help("Open")
            }
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
    }
}

// MARK: - Generic Dialog Component

struct GenericDialog<Content: View>: View {
    let title: String
    let content: Content
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let confirmTitle: String
    let isConfirmDisabled: Bool
    
    init(
        title: String,
        confirmTitle: String = "Add",
        isConfirmDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.isConfirmDisabled = isConfirmDisabled
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2).fontWeight(.bold)
                .padding(.bottom, 12)
            
            content
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button(confirmTitle) { onConfirm() }
                    .disabled(isConfirmDisabled)
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(width: 420, height: 340)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Dialog Content Views

struct AddAppDialogContent: View {
    enum Tab { case browse, running, manual }
    @State private var selectedTab: Tab = .browse
    @State private var manualName: String = ""
    @State private var manualBundle: String = ""
    @State private var manualWindowTitle: String = ""
    @State private var selectedRunningAppPIDs: Set<pid_t> = []
    @State private var browseAppName: String = ""
    @State private var browseBundle: String = ""
    @State private var browseWindowTitle: String = ""
    @State private var showOpenPanel = false
    var onAdd: (AppItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Method", selection: $selectedTab) {
                Text("Browse").tag(Tab.browse)
                Text("Running Apps").tag(Tab.running)
                Text("Manual").tag(Tab.manual)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 16)
            
            if selectedTab == .browse {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Choose Application...") {
                        showOpenPanel = true
                    }
                    if !browseAppName.isEmpty {
                        Text("Name: \(browseAppName)")
                        Text("Bundle ID: \(browseBundle)")
                        TextField("Window Title (optional)", text: $browseWindowTitle)
                    }
                }
            } else if selectedTab == .running {
                let runningApps = NSWorkspace.shared.runningApplications
                    .filter { $0.bundleIdentifier != nil && $0.activationPolicy == .regular }
                    .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
                List(runningApps, id: \.processIdentifier) { app in
                    HStack {
                        Text(app.localizedName ?? "Unknown")
                        Spacer()
                        Text(app.bundleIdentifier ?? "")
                        if selectedRunningAppPIDs.contains(app.processIdentifier) {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedRunningAppPIDs.contains(app.processIdentifier) {
                            selectedRunningAppPIDs.remove(app.processIdentifier)
                        } else {
                            selectedRunningAppPIDs.insert(app.processIdentifier)
                        }
                    }
                }
            } else if selectedTab == .manual {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("App Name", text: $manualName)
                    TextField("Bundle Identifier", text: $manualBundle)
                    TextField("Window Title (optional)", text: $manualWindowTitle)
                }
            }
        }
        .onChange(of: showOpenPanel) { oldValue, newValue in
            if newValue {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [UTType.application]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                if panel.runModal() == .OK, let url = panel.url {
                    if let bundle = Bundle(url: url),
                       let bundleId = bundle.bundleIdentifier {
                        browseAppName = url.deletingPathExtension().lastPathComponent
                        browseBundle = bundleId
                    } else {
                        browseAppName = url.deletingPathExtension().lastPathComponent
                        browseBundle = ""
                    }
                }
                showOpenPanel = false
            }
        }
    }
    
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

struct AddDocumentDialogContent: View {
    enum Tab { case browse, opened }
    @State private var selectedTab: Tab = .browse
    @State private var docName: String = ""
    @State private var docPath: String = ""
    @State private var docApp: String = ""
    @State private var showOpenPanel = false
    @State private var bookmark: Data? = nil
    var onAdd: (DocumentItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Method", selection: $selectedTab) {
                Text("Browse").tag(Tab.browse)
                Text("Opened Documents").tag(Tab.opened)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 16)
            
            if selectedTab == .browse {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Choose Document...") {
                        showOpenPanel = true
                    }
                    if !docPath.isEmpty {
                        Text("Name: \(docName)")
                        Text("Path: \(docPath)")
                        TextField("Application (optional)", text: $docApp)
                    }
                }
            } else if selectedTab == .opened {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No opened documents detected.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: showOpenPanel) { oldValue, newValue in
            if newValue {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                if panel.runModal() == .OK, let url = panel.url {
                    docName = url.deletingPathExtension().lastPathComponent
                    docPath = url.path
                    do {
                        bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    } catch {
                        bookmark = nil
                    }
                }
                showOpenPanel = false
            }
        }
    }
    
    func createDocumentItem() -> DocumentItem {
        return DocumentItem(name: docName, filePath: docPath, application: docApp.isEmpty ? "" : docApp, bookmark: bookmark)
    }
    
    var isConfirmDisabled: Bool {
        docName.isEmpty || docPath.isEmpty
    }
}

struct AddBrowserTabDialogContent: View {
    @State private var tabTitle: String = ""
    @State private var tabURL: String = ""
    @State private var selectedBrowser: String = "Default"
    
    let availableBrowsers = ["Safari", "Chrome", "Firefox", "Default"]
    var onAdd: (BrowserTab) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Tab Title", text: $tabTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("URL", text: $tabURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .placeholder(when: tabURL.isEmpty) {
                    Text("https://example.com")
                        .foregroundColor(.secondary)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Browser")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Browser", selection: $selectedBrowser) {
                    ForEach(availableBrowsers, id: \.self) { browser in
                        Text(browser).tag(browser)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    func createBrowserTab() -> BrowserTab {
        let browser = selectedBrowser == "Default" ? "default" : selectedBrowser
        return BrowserTab(
            title: tabTitle.isEmpty ? tabURL : tabTitle,
            url: tabURL,
            browser: browser
        )
    }
    
    var isConfirmDisabled: Bool {
        tabURL.isEmpty
    }
}

// MARK: - Dialog Wrappers

struct AddAppDialog: View {
    var onAdd: (AppItem) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GenericDialog(
            title: "Add Application",
            onCancel: onCancel,
            onConfirm: {
                let content = AddAppDialogContent(onAdd: onAdd)
                if let appItem = content.createAppItem() {
                    onAdd(appItem)
                }
            }
        ) {
            AddAppDialogContent(onAdd: onAdd)
        }
    }
}

struct AddDocumentDialog: View {
    var onAdd: (DocumentItem) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GenericDialog(
            title: "Add Document",
            onCancel: onCancel,
            onConfirm: {
                let content = AddDocumentDialogContent(onAdd: onAdd)
                onAdd(content.createDocumentItem())
            }
        ) {
            AddDocumentDialogContent(onAdd: onAdd)
        }
    }
}

struct AddBrowserTabDialog: View {
    var onAdd: (BrowserTab) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GenericDialog(
            title: "Add Browser Tab",
            onCancel: onCancel,
            onConfirm: {
                let content = AddBrowserTabDialogContent(onAdd: onAdd)
                onAdd(content.createBrowserTab())
            }
        ) {
            AddBrowserTabDialogContent(onAdd: onAdd)
        }
    }
}

struct EditableContextName: View {
    @State private var isEditing = false
    @State private var draftName: String
    var name: String
    var onCommit: (String) -> Void
    
    init(name: String, onCommit: @escaping (String) -> Void) {
        self.name = name
        self.onCommit = onCommit
        _draftName = State(initialValue: name)
    }
    
    var body: some View {
        Group {
            if isEditing {
                TextField("Context Name", text: $draftName, onCommit: {
                    isEditing = false
                    if !draftName.trimmingCharacters(in: .whitespaces).isEmpty && draftName != name {
                        onCommit(draftName)
                    }
                })
                .font(.system(size: 28, weight: .bold))
                .textFieldStyle(PlainTextFieldStyle())
                .onAppear { DispatchQueue.main.async { self.isEditing = true } }
                .onExitCommand { isEditing = false }
                .onSubmit {
                    isEditing = false
                    if !draftName.trimmingCharacters(in: .whitespaces).isEmpty && draftName != name {
                        onCommit(draftName)
                    }
                }
            } else {
                Text(name)
                    .font(.system(size: 28, weight: .bold))
                    .onTapGesture { 
                        draftName = name
                        isEditing = true 
                    }
            }
        }
        .frame(minWidth: 120, alignment: .leading)
        .onChange(of: name) { oldValue, newName in
            isEditing = false
            draftName = newName
        }
    }
}

// MARK: - Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}


