import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit

struct ContextItemRow: View {
    let item: ContextItem
    let onOpen: (() -> Void)?
    let onDelete: (() -> Void)?
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 22, height: 22)
                .foregroundColor(iconColor)
                .padding(6)
                .background(Circle().fill(iconColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        // .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
        .contentShape(Rectangle())
    }
    private var icon: String {
        switch item {
        case .application: return "folder"
        case .document: return "doc"
        case .browserTab: return "globe"
        case .terminalSession: return "terminal"
        }
    }
    private var iconColor: Color {
        switch item {
        case .application: return .blue
        case .document: return .orange
        case .browserTab: return .purple
        case .terminalSession: return .green
        }
    }
    private var title: String {
        switch item {
        case .application(let app): return app.name
        case .document(let doc): return doc.name
        case .browserTab(let tab): return tab.title
        case .terminalSession(let term): return term.title
        }
    }
    private var subtitle: String? {
        switch item {
        case .application(let app): return app.bundleIdentifier
        case .document(let doc): return doc.filePath
        case .browserTab(let tab): return tab.url
        case .terminalSession(let term): return term.command ?? term.workingDirectory
        }
    }
}

struct ContextDetailsView: View {
    @ObservedObject var contextManager: ContextManager
    @Binding var selectedContextID: UUID?
    @Binding var showAddAppDialog: Bool
    @Binding var showAddDocumentDialog: Bool
    @Binding var showAddBrowserTabDialog: Bool
    @Binding var showAddTerminalDialog: Bool
    
    @State private var isEditingTitle = false
    @State private var draftTitle = ""
    @State private var showAddMenu = false
    
    var body: some View {
        ZStack {
            if let contextIdx = contextManager.contexts.firstIndex(where: { $0.id == selectedContextID }) {
                let context = contextManager.contexts[contextIdx]
                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
                        if context.items.isEmpty {
                            VStack {
                                Spacer()
                                Text("Use the + button above or drag and drop apps, documents, or files here to add them to this context.")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(context.items.indices, id: \.self) { idx in
                                    makeRow(for: context.items[idx], contextIdx: contextIdx, itemIndex: idx)
                                }
                                .onMove { indices, newOffset in
                                    contextManager.contexts[contextIdx].items.move(fromOffsets: indices, toOffset: newOffset)
                                    contextManager.saveContexts()
                                }
                            }
                            .listStyle(.inset)
                            .background(Color.clear)
                            .clipShape(TopRoundedRectangle(radius: 16))
                            .overlay(
                                TopRoundedRectangle(radius: 16)
                                    .stroke(Color.gray.opacity(0.13), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
                            .onDrop(of: [UTType.fileURL, UTType.url, UTType.text, UTType.plainText], isTargeted: nil) { providers in
                                UniversalDropHandler.handleUniversalDrop(providers: providers, contextManager: contextManager, selectedContextID: selectedContextID)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
                .sheet(isPresented: $showAddAppDialog) {
                    AddAppDialog(
                        onAdd: { newApp in
                            contextManager.contexts[contextIdx].items.append(.application(newApp))
                            contextManager.saveContexts()
                            showAddAppDialog = false
                        },
                        onCancel: { showAddAppDialog = false }
                    )
                }
                .sheet(isPresented: $showAddDocumentDialog) {
                    AddDocumentDialog(
                        onAdd: { newDoc in
                            contextManager.contexts[contextIdx].items.append(.document(newDoc))
                            contextManager.saveContexts()
                            showAddDocumentDialog = false
                        },
                        onCancel: { showAddDocumentDialog = false }
                    )
                }
                .sheet(isPresented: $showAddBrowserTabDialog) {
                    AddBrowserTabDialog(
                        onAdd: { newTab in
                            contextManager.contexts[contextIdx].items.append(.browserTab(newTab))
                            contextManager.saveContexts()
                            showAddBrowserTabDialog = false
                        },
                        onCancel: { showAddBrowserTabDialog = false }
                    )
                }
                .sheet(isPresented: $showAddTerminalDialog) {
                    AddTerminalDialog(
                        onAdd: { newTerm in
                            contextManager.contexts[contextIdx].items.append(.terminalSession(newTerm))
                            contextManager.saveContexts()
                            showAddTerminalDialog = false
                        },
                        onCancel: { showAddTerminalDialog = false }
                    )
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select or add a context to view details.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if let contextIdx = contextManager.contexts.firstIndex(where: { $0.id == selectedContextID }) {
                    let context = contextManager.contexts[contextIdx]
                    if isEditingTitle {
                        TextField("Context Name", text: $draftTitle, onCommit: {
                            isEditingTitle = false
                            let trimmed = draftTitle.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty && trimmed != context.name {
                                contextManager.contexts[contextIdx].name = trimmed
                                contextManager.saveContexts()
                            }
                        })
                        .font(.system(size: 17, weight: .bold))
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(minWidth: 120, maxWidth: 300)
                        .onAppear { draftTitle = context.name }
                        .onExitCommand { isEditingTitle = false }
                    } else {
                        Text(context.name)
                            .font(.system(size: 17, weight: .bold))
                            .onTapGesture {
                                draftTitle = context.name
                                isEditingTitle = true
                            }
                    }
                }
            }
            ToolbarItemGroup(placement: .automatic) {
                // Add dropdown menu for adding items (unchanged)
                Menu {
                    Button("Application", action: { showAddAppDialog = true })
                    Button("Document", action: { showAddDocumentDialog = true })
                    Button("Browser Tab", action: { showAddBrowserTabDialog = true })
                    Button("Shell Script", action: { showAddTerminalDialog = true })
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .help("Add Item")
                }
                // Single switching mode button + menu
                if let contextIdx = contextManager.contexts.firstIndex(where: { $0.id == selectedContextID }) {
                    let context = contextManager.contexts[contextIdx]
                    Menu {
                        ForEach(SwitchingMode.allCases, id: \ .self) { mode in
                            Button(action: {
                                contextManager.switchToContext(context, switchingMode: mode)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: iconForSwitchingMode(mode))
                                        .font(.caption)
                                    Text(mode.rawValue)
                                        .font(.caption)
                                }
                            }
                            .help(mode.description)
                        }
                    } label: {
                        Button(action: {
                            contextManager.switchToContext(context, switchingMode: .additive)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.square") // Explicit open icon
                                Text("Open")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(colorForSwitchingMode(.additive))
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .help("Switch context (default: Additive)")
                    }
                    Button(action: {
                        contextManager.closeContext(context)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                            Text("Close")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.red.opacity(0.7)) // Lighter red
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Close context")
                }
            }
        }
        .navigationTitle("")
        .onChange(of: selectedContextID) { _, _ in
            isEditingTitle = false
        }
    }
    
    private func onOpenAction(for item: ContextItem, contextIdx: Int) -> (() -> Void)? {
        switch item {
        case .application(let app):
            return { contextManager.openApp(app) }
        case .document(let doc):
            return { contextManager.openDocument(doc) }
        case .browserTab(let tab):
            return { contextManager.openBrowserTab(tab) }
        case .terminalSession:
            return nil
        }
    }
    
    private func makeRow(for item: ContextItem, contextIdx: Int, itemIndex: Int) -> some View {
        ContextItemRow(
            item: item,
            onOpen: onOpenAction(for: item, contextIdx: contextIdx),
            onDelete: {
                contextManager.contexts[contextIdx].items.remove(at: itemIndex)
                contextManager.saveContexts()
            }
        )
        .listRowInsets(EdgeInsets())
        .background(Color.clear)
    }
    
    // Helper for icon
    private func iconForSwitchingMode(_ mode: SwitchingMode) -> String {
        switch mode {
        case .replaceAll:
            return "arrow.triangle.2.circlepath"
        case .additive:
            return "plus.circle"
        case .hybrid:
            return "brain.head.profile"
        }
    }
    
    private var selectedContextName: String {
        if let id = selectedContextID, let context = contextManager.contexts.first(where: { $0.id == id }) {
            return context.name
        }
        return "Context"
    }
    
    private func colorForSwitchingMode(_ mode: SwitchingMode) -> Color {
        switch mode {
        case .replaceAll:
            return Color.blue
        case .additive:
            return Color.green
        case .hybrid:
            return Color.purple
        }
    }
}

struct TopRoundedRectangle: Shape {
    var radius: CGFloat = 16.0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        let tr = min(min(radius, height/2), width/2)
        let tl = tr

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tl, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + tr),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
