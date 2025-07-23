import SwiftUI
import UniformTypeIdentifiers

struct ContextSidebarView: View {
    @ObservedObject var contextManager: ContextManager
    @Binding var selectedContextID: UUID?
    @Binding var showDeleteAlert: Bool
    @StateObject private var permissionsManager = PermissionsManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
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
                    if selectedContextID != nil {
                        showDeleteAlert = true
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
            List(selection: $selectedContextID) {
                ForEach(contextManager.contexts) { context in
                    HStack(spacing: 0) {
                        // Main content
                        ContextCardView(
                            context: context,
                            isSelected: context.id == selectedContextID,
                            onIconChange: { iconName, backgroundColorHex, foregroundColorHex in
                                if let index = contextManager.contexts.firstIndex(where: { $0.id == context.id }) {
                                    contextManager.contexts[index].iconName = iconName
                                    contextManager.contexts[index].iconBackgroundColor = backgroundColorHex
                                    contextManager.contexts[index].iconForegroundColor = foregroundColorHex
                                    contextManager.saveContexts()
                                }
                            }
                        )
                        .contentShape(Rectangle())
                        .tag(context.id as UUID?)
                        .onDrop(of: [UTType.fileURL, UTType.url, UTType.text, UTType.plainText], isTargeted: nil) { providers in
                            UniversalDropHandler.handleUniversalDrop(providers: providers, contextManager: contextManager, selectedContextID: context.id)
                        }
                        Spacer(minLength: 0)
                        // Dot indicator at top right
                        VStack(alignment: .trailing, spacing: 0) {
                            Circle()
                                .fill(
                                    contextManager.isActive(context: context)
                                        ? Color("ActiveContextColor")
                                        : Color.clear
                                )
                                .frame(width: 8, height: 8)
                                .padding(.top, -4) // Adjust as needed for icon alignment
                            Spacer()
                        }
                        .frame(height: 32) // Adjust to match row/icon height
                        .padding(.trailing, 8)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.15), lineWidth: context.id == selectedContextID ? 0 : 1)
                    )
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
            Alert(
                title: Text("Delete Context"),
                message: Text("Are you sure you want to delete this context?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let id = selectedContextID, let context = contextManager.contexts.first(where: { $0.id == id }) {
                        contextManager.deleteContext(context)
                        selectedContextID = nil
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
} 
