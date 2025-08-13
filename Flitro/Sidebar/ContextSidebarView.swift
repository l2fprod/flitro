import SwiftUI
import UniformTypeIdentifiers

struct ContextSidebarView: View {
    @ObservedObject var contextManager: ContextManager
    @Binding var selectedContextID: UUID?
    @Binding var showDeleteAlert: Bool
    @StateObject private var permissionsManager = PermissionsManager.shared
    
    private var headerView: some View {
        HStack {
            Text("Contexts")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button(action: {
                let newContext = Context(name: "New Context", items: [], iconName: nil)
                contextManager.addContext(newContext)
                selectedContextID = newContext.id
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(nsColor: NSColor.systemGray))
            }
            .buttonStyle(.plain)
            .help("Add Context")
            Button(action: {
                if let id = selectedContextID, let ctx = contextManager.contexts.first(where: { $0.id == id }) {
                    if ctx.items.isEmpty {
                        contextManager.deleteContext(contextID: id)
                        selectedContextID = nil
                    } else {
                        showDeleteAlert = true
                    }
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(nsColor: NSColor.systemGray))
            }
            .buttonStyle(.plain)
            .disabled(selectedContextID == nil)
            .help("Delete Context")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }
    
    private func contextRow(for context: Context) -> some View {
        // Main content
        ContextCardView(
            context: context,
            isSelected: context.id == selectedContextID
        )
        .onDrop(of: UniversalDropHandler.allDropTypes, isTargeted: nil) { providers in
            UniversalDropHandler.handleUniversalDrop(providers: providers, contextManager: contextManager, selectedContextID: context.id)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.15), lineWidth: context.id == selectedContextID ? 0 : 1)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
             List(selection: $selectedContextID) {
                 ForEach(contextManager.contexts, id: \.id) { context in
                     contextRow(for: context)
                 }
                 .onMove { indices, newOffset in
                     contextManager.reorderContexts(fromOffsets: indices, toOffset: newOffset)
                 }
             }
             .listStyle(.sidebar)
             .frame(maxWidth: .infinity, alignment: .leading)

            // Permissions button at the bottom
             if !permissionsManager.hasAllPermissions {
                 VStack(spacing: 0) {
                     Divider()
                     Button(action: {
                         permissionsManager.showPermissionDialog()
                     }) {
                         HStack {
                             Image(systemName: permissionsManager.hasAllPermissions ? "checkmark.shield" : "exclamationmark.shield")
                                 .foregroundColor(permissionsManager.hasAllPermissions ? .green : .orange)
                             Text(permissionsManager.permissionStatusMessage)
                                 .font(.caption)
                             Spacer()
                         }
                         .padding(.horizontal, 12)
                         .padding(.vertical, 8)
                     }
                     .buttonStyle(.plain)
                     .background(Color(NSColor.controlBackgroundColor))
                     .help("Configure permissions")
                 }
             }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            permissionsManager.checkPermissions()
        }
        .alert(isPresented: $showDeleteAlert) {
            let contextName = contextManager.contexts.first(where: { $0.id == selectedContextID })?.name ?? "this context"
            return Alert(
                title: Text("Delete Context"),
                message: Text("Are you sure you want to delete \(contextName)?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let id = selectedContextID, let context = contextManager.contexts.first(where: { $0.id == id }) {
                        contextManager.deleteContext(contextID: context.id)
                        selectedContextID = nil
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
}
