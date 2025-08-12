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
            if let selectedContext = selectedContext {
                ContextDetailsView(
                    context: selectedContext,
                    contextManager: contextManager,
                    showAddAppDialog: $showAddAppDialog,
                    showAddDocumentDialog: $showAddDocumentDialog,
                    showAddBrowserTabDialog: $showAddBrowserTabDialog,
                    showAddTerminalDialog: $showAddTerminalDialog
                ).onDrop(of: UniversalDropHandler.allDropTypes, isTargeted: nil) { providers in
                return UniversalDropHandler.handleUniversalDrop(providers: providers, contextManager: contextManager, selectedContextID: selectedContextID)
                }
            } else {
                Text("Select or add a context to view details.")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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




