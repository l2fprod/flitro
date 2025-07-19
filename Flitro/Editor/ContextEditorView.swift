import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit
import PhosphorSwift

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
                return UniversalDropHandler.handleUniversalDrop(providers: providers, contextManager: contextManager, selectedContextID: selectedContextID)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct UniversalDropHandler {
    static func handleUniversalDrop(providers: [NSItemProvider], contextManager: ContextManager, selectedContextID: UUID?) -> Bool {
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
                                if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                                    let appItem = AppItem(name: url.deletingPathExtension().lastPathComponent, bundleIdentifier: bundleId, windowTitle: nil)
                                    contextManager.contexts[contextIndex].items.append(.application(appItem))
                                    contextManager.saveContexts()
                                    print("Added application: \(appItem.name)")
                                }
                            } else if url.pathExtension == "sh" {
                                let session = TerminalSession(
                                    workingDirectory: url.deletingLastPathComponent().path,
                                    command: url.path,
                                    title: url.deletingPathExtension().lastPathComponent
                                )
                                contextManager.contexts[contextIndex].items.append(.terminalSession(session))
                                contextManager.saveContexts()
                                print("Added terminal session for script: \(session.title)")
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
                                contextManager.contexts[contextIndex].items.append(.document(document))
                                contextManager.saveContexts()
                                print("Added document: \(document.name)")
                            } else {
                                // Fallback: add as document for any other file type
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
                                contextManager.contexts[contextIndex].items.append(.document(document))
                                contextManager.saveContexts()
                                print("Added document: \(document.name)")
                            }
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier("public.shell-script") {
                provider.loadItem(forTypeIdentifier: "public.shell-script", options: nil) { item, error in
                    if let error = error {
                        print("Error loading shell script: \(error)")
                        return
                    }
                    var url: URL?
                    if let urlObject = item as? URL {
                        url = urlObject
                    } else if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                        print("Converted data to URL: \(String(describing: url))")
                    }
                    if let url = url {
                        DispatchQueue.main.async {
                            let session = TerminalSession(
                                workingDirectory: url.deletingLastPathComponent().path,
                                command: url.path,
                                title: url.deletingPathExtension().lastPathComponent
                            )
                            contextManager.contexts[contextIndex].items.append(.terminalSession(session))
                            contextManager.saveContexts()
                            print("Added terminal session for script: \(session.title)")
                        }
                    }
                }
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                        DispatchQueue.main.async {
                            contextManager.contexts[contextIndex].items.append(.browserTab(browserTab))
                            contextManager.saveContexts()
                        }
                    } else if let url = item as? URL {
                        let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                        DispatchQueue.main.async {
                            contextManager.contexts[contextIndex].items.append(.browserTab(browserTab))
                            contextManager.saveContexts()
                        }
                    }
                }
                handled = true
                let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) ? UTType.text.identifier : UTType.plainText.identifier
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                    if let text = item as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                            DispatchQueue.main.async {
                                contextManager.contexts[contextIndex].items.append(.browserTab(browserTab))
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

struct GenericDialog<Content: View>: View {
    let title: String
    let content: Content
    let onCancel: () -> Void
    let onConfirm: (Content) -> Void
    let confirmTitle: String
    let isConfirmDisabled: Bool
    
    init(
        title: String,
        confirmTitle: String = "Add",
        isConfirmDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (Content) -> Void,
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
                Button(confirmTitle) { onConfirm(content) }
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

extension UTType {
    static var shellScript: UTType {
        UTType(importedAs: "public.shell-script")
    }
}


