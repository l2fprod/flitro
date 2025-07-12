import SwiftUI

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
                    let newContext = Context(name: "New Context", applications: [], documents: [], browserTabs: [], terminalSessions: [], iconName: nil)
                    contextManager.contexts.append(newContext)
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
                    ContextCardView(
                        context: context,
                        isSelected: context.id == selectedContextID,
                        onSelect: { selectedContextID = context.id },
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
                }
                .onMove { indices, newOffset in
                    contextManager.reorderContexts(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .listStyle(.sidebar)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Permissions button at the bottom
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
                .help("Configure accessibility and automation permissions")
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
