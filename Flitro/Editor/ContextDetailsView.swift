import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit
import Combine

struct ContextItemRow: View {
    let item: ContextItem
    let contextManager: ContextManager
    let onOpen: (() -> Void)?
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 16) {
            if let iconImage = iconImage {
                Image(nsImage: iconImage)
                    .resizable()
                    .frame(width: 34, height: 34)
            } else {
                Image(systemName: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundColor(iconColor)
                    .padding(6)
                    .background(Circle().fill(iconColor.opacity(0.12)))
            }
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
    
    // Helper to get the correct NSImage for the item
    private var iconImage: NSImage? {
        return contextManager.icon(for: item)
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
                        TopRoundedRectangle(radius: 16)
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
                                    contextManager.moveItems(fromOffsets: indices, toOffset: newOffset, in: contextManager.contexts[contextIdx].id)
                                }
                            }
                            .listStyle(.inset)
                            .background(Color.clear)
                            .clipShape(TopRoundedRectangle(radius: 16))
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
                            contextManager.addItem(.application(newApp), to: contextManager.contexts[contextIdx].id)
                            showAddAppDialog = false
                        },
                        onCancel: { showAddAppDialog = false }
                    )
                    .presentationDetents([.height(480)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(16)
                }
                .sheet(isPresented: $showAddDocumentDialog) {
                    AddDocumentDialog(
                        onAdd: { newDoc in
                            contextManager.addItem(.document(newDoc), to: contextManager.contexts[contextIdx].id)
                            showAddDocumentDialog = false
                        },
                        onCancel: { showAddDocumentDialog = false }
                    )
                    .presentationDetents([.height(480)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(16)
                }
                .sheet(isPresented: $showAddBrowserTabDialog) {
                    AddBrowserTabDialog(
                        onAdd: { newTab in
                            contextManager.addItem(.browserTab(newTab), to: contextManager.contexts[contextIdx].id)
                            showAddBrowserTabDialog = false
                        },
                        onCancel: { showAddBrowserTabDialog = false }
                    )
                    .presentationDetents([.height(480)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(16)
                }
                .sheet(isPresented: $showAddTerminalDialog) {
                    AddTerminalDialog(
                        onAdd: { newTerm in
                            contextManager.addItem(.terminalSession(newTerm), to: contextManager.contexts[contextIdx].id)
                            showAddTerminalDialog = false
                        },
                        onCancel: { showAddTerminalDialog = false }
                    )
                    .presentationDetents([.height(480)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(16)
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
                Rectangle()
                    .frame(width: 1, height: 24)
                    .foregroundColor(Color.gray.opacity(0.3))
                    .padding(.horizontal, 4)
                // Single context button
                if let contextIdx = contextManager.contexts.firstIndex(where: { $0.id == selectedContextID }) {
                    let context = contextManager.contexts[contextIdx]
                    ContextButton(context: context, contextManager: contextManager)
                }
            }
        }
        .navigationTitle("")
        .onChange(of: selectedContextID) { _, _ in
            isEditingTitle = false
        }
    }
    
    private func onOpenAction(for item: ContextItem, contextIdx: Int) -> (() -> Void)? {
        return { contextManager.openItem(item) }
    }
    
    private func makeRow(for item: ContextItem, contextIdx: Int, itemIndex: Int) -> some View {
        ContextItemRow(
            item: item,
            contextManager: contextManager,
            onOpen: onOpenAction(for: item, contextIdx: contextIdx),
            onDelete: {
                contextManager.removeItem(at: itemIndex, from: contextManager.contexts[contextIdx].id)
            }
        )
        .listRowInsets(EdgeInsets())
        .background(Color.clear)
    }

    private var selectedContextName: String {
        if let id = selectedContextID, let context = contextManager.contexts.first(where: { $0.id == id }) {
            return context.name
        }
        return "Context"
    }
}

struct ContextButton: View {
    let context: Context
    @ObservedObject var contextManager: ContextManager
    @State private var isOptionPressed = false

    var body: some View {
        Button(action: buttonAction) {
            HStack(spacing: 6) {
                Image(systemName: buttonIcon)
                Text(buttonText)
            }
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(buttonBackgroundColor)
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .help(buttonHelpText)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            // Only track Option key when window is active
            if NSApp.isActive {
                isOptionPressed = NSEvent.modifierFlags.contains(.option)
            } else {
                isOptionPressed = false
            }
        }
    }

    private var isActive: Bool {
        contextManager.isActive(contextID: context.id)
    }

    private var buttonText: String {
        if isActive && isOptionPressed {
            return "Close All"
        } else if isActive {
            return "Close"
        } else if isOptionPressed {
            return "Close Others and Open"
        } else {
            return "Open"
        }
    }

    private var buttonIcon: String {
        if isActive && isOptionPressed {
            return "xmark.circle"
        } else if isActive {
            return "xmark"
        } else if isOptionPressed {
            return "arrow.triangle.2.circlepath"
        } else {
            return "arrow.right.square"
        }
    }

    private var buttonBackgroundColor: Color {
        if isActive && isOptionPressed {
            return Color.red
        } else if isActive {
            return Color.red.opacity(0.8)
        } else if isOptionPressed {
            return Color.blue
        } else {
            return Color.green
        }
    }

    private var buttonHelpText: String {
        if isActive && isOptionPressed {
            return "Close all active contexts"
        } else if isActive {
            return "Close this context"
        } else if isOptionPressed {
            return "Close all active contexts and open this one (Replace All mode)"
        } else {
            return "Open this context (Additive mode)"
        }
    }

    private func buttonAction() {
        if isActive && isOptionPressed {
            contextManager.closeAllContexts()
        } else if isActive {
            contextManager.closeContext(contextID: context.id)
        } else if isOptionPressed {
            contextManager.closeAllContexts()
            contextManager.switchToContext(contextID: context.id)
        } else {
            contextManager.switchToContext(contextID: context.id)
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
