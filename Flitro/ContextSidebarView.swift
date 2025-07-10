import SwiftUI

struct ContextSidebarView: View {
    @ObservedObject var contextManager: ContextManager
    @Binding var selectedContextID: UUID?
    @Binding var showDeleteAlert: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Contexts")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    let newContext = Context(name: "New Context", applications: [], documents: [], browserTabs: [], terminalSessions: [])
                    contextManager.contexts.append(newContext)
                    selectedContextID = newContext.id
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Add Context")
                Button(action: {
                    if selectedContextID != nil {
                        showDeleteAlert = true
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.title2)
                        .foregroundColor(selectedContextID == nil ? .gray : .primary)
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
                        onSelect: { selectedContextID = context.id }
                    )
                    .contentShape(Rectangle())
                    .tag(context.id as UUID?)
                    .listRowBackground(EmptyView())
                }
            }
            .listStyle(.sidebar)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
} 