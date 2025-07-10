import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit

struct ContextDetailsView: View {
    @ObservedObject var contextManager: ContextManager
    @Binding var selectedContextID: UUID?
    @Binding var showAddAppDialog: Bool
    @Binding var showAddDocumentDialog: Bool
    @Binding var showAddBrowserTabDialog: Bool
    @Binding var showAddTerminalDialog: Bool
    
    @State private var isEditingTitle = false
    @State private var draftTitle = ""
    
    var body: some View {
        ZStack {
            if let contextIdx = contextManager.contexts.firstIndex(where: { $0.id == selectedContextID }) {
                let context = contextManager.contexts[contextIdx]
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Applications Card
                        CardSection(
                            title: "Applications",
                            items: context.applications.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.enumerated().map { (idx, app) in
                                CardRow(
                                    icon: "folder",
                                    title: app.name,
                                    subtitle: app.bundleIdentifier,
                                    onDelete: {
                                        contextManager.contexts[contextIdx].applications.removeAll { $0.id == app.id }
                                    }
                                )
                            },
                            onAdd: {
                                showAddAppDialog = true
                            }
                        )
                        // Documents Card
                        CardSection(
                            title: "Documents",
                            items: context.documents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.enumerated().map { (idx, doc) in
                                CardRow(
                                    icon: "doc",
                                    title: doc.name,
                                    subtitle: doc.filePath,
                                    onDelete: {
                                        contextManager.contexts[contextIdx].documents.removeAll { $0.id == doc.id }
                                    }
                                )
                            },
                            onAdd: {
                                showAddDocumentDialog = true
                            }
                        )
                        .sheet(isPresented: $showAddDocumentDialog) {
                            AddDocumentDialog(
                                onAdd: { newDoc in
                                    contextManager.contexts[contextIdx].documents.append(newDoc)
                                    showAddDocumentDialog = false
                                },
                                onCancel: { showAddDocumentDialog = false }
                            )
                        }
                        // Browser Tabs Card
                        CardSection(
                            title: "Browser Tabs", 
                            items: context.browserTabs.enumerated().map { (idx, tab) in
                                CardRow(
                                    icon: "globe",
                                    title: tab.title,
                                    subtitle: tab.url,
                                    onDelete: {
                                        contextManager.contexts[contextIdx].browserTabs.removeAll { $0.id == tab.id }
                                        contextManager.saveContexts()
                                    }
                                )
                            },
                            onAdd: {
                                showAddBrowserTabDialog = true
                            }
                        )
                        .sheet(isPresented: $showAddBrowserTabDialog) {
                            AddBrowserTabDialog(
                                onAdd: { newTab in
                                    contextManager.contexts[contextIdx].browserTabs.append(newTab)
                                    contextManager.saveContexts()
                                    showAddBrowserTabDialog = false
                                },
                                onCancel: { showAddBrowserTabDialog = false }
                            )
                        }
                        // Terminals Card
                        CardSection(title: "Terminals", items: context.terminalSessions.enumerated().map { (idx, term) in
                            CardRow(icon: "terminal", title: term.title, subtitle: term.command ?? term.workingDirectory, onDelete: {
                                contextManager.contexts[contextIdx].terminalSessions.removeAll { $0.id == term.id }
                                contextManager.saveContexts()
                            })
                        }, onAdd: {
                            showAddTerminalDialog = true
                        })
                        .sheet(isPresented: $showAddTerminalDialog) {
                            AddTerminalDialog(
                                onAdd: { newTerm in
                                    contextManager.contexts[contextIdx].terminalSessions.append(newTerm)
                                    contextManager.saveContexts()
                                    showAddTerminalDialog = false
                                },
                                onCancel: { showAddTerminalDialog = false }
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sheet(isPresented: $showAddAppDialog) {
                    AddAppDialog(
                        onAdd: { newApp in
                            contextManager.contexts[contextIdx].applications.append(newApp)
                            showAddAppDialog = false
                        },
                        onCancel: { showAddAppDialog = false }
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
            if let contextIdx = contextManager.contexts.firstIndex(where: { $0.id == selectedContextID }) {
                let context = contextManager.contexts[contextIdx]
                ToolbarItemGroup(placement: .automatic) {
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(colorForSwitchingMode(mode))
                            )
                            .foregroundColor(.white)
                        }
                        .help(mode.description)
                        .buttonStyle(.plain)
                    }
                    Button("Close") {
                        contextManager.closeContextApplications(context)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.red)
                    )
                    .foregroundColor(.white)
                }
            }
        }
        .navigationTitle("")
        .onChange(of: selectedContextID) { _, _ in
            isEditingTitle = false
        }
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
