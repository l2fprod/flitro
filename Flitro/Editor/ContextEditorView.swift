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
            .environmentObject(contextManager)
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
    let icon: String
    let subtitle: String
    let content: Content
    let onCancel: () -> Void
    let onConfirm: (Content) -> Void
    let confirmTitle: String
    let isConfirmDisabled: Bool
    
    init(
        title: String,
        icon: String,
        subtitle: String,
        confirmTitle: String = "Add",
        isConfirmDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (Content) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.confirmTitle = confirmTitle
        self.isConfirmDisabled = isConfirmDisabled
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with icon and title
            HStack(spacing: 12) {
                // Icon provided by the dialog
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.bottom, 20)
            
            // Content area
            content
                .padding(.horizontal, 4)
            
            Spacer()
            
            // Footer with buttons
            HStack(spacing: 12) {
                Button("Cancel") { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onCancel() 
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 0.1), value: true)
                
                Spacer()
                
                Button(confirmTitle) { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onConfirm(content) 
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isConfirmDisabled)
                .scaleEffect(isConfirmDisabled ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isConfirmDisabled)
            }
            .padding(.top, 24)
        }
        .padding(28)
        .frame(width: 480, height: 480)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
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


