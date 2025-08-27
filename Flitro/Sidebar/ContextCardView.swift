import SwiftUI
import PhosphorSwift
import Foundation

// MARK: - Context Card View

struct ContextCardView: View {
    @ObservedObject var context: Context
    let isSelected: Bool
    
    @State private var showIconSelector = false
    @State private var showDeleteAlert = false
    @State private var iconRotation: Double = 0
    @State private var cardScale: CGFloat = 1.0
    @EnvironmentObject private var contextManager: ContextManager
    @State private var isRenaming = false
    @State private var draftName: String = ""
    @FocusState private var renameFieldFocused: Bool

    private var itemCountText: String {
        let total = context.items.count
        return "\(total) items"
    }
    
    private var isActive: Bool {
        contextManager.isActive(contextID: context.id)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ContextIconView(
                context: context,
                size: 32,
                animate: true,
                rotation: iconRotation
            )
            .scaleEffect(cardScale)
            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    TextField("Rename Context", text: $draftName)
                        .textFieldStyle(.plain)
                        .focused($renameFieldFocused)
                        .onSubmit { commitRename() }
                        .onExitCommand { cancelRename() }
                        .onChange(of: renameFieldFocused) { _, focused in
                            if !focused { commitRename() }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.textBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15))
                                )
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(2)
                } else {
                    Text(context.name)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            if !isRenaming {
                Text(itemCountText)
                    .font(.footnote)
                // // Dot indicator at top right
                VStack(alignment: .trailing, spacing: 0) {
                    Circle()
                        .fill(isActive ? Color("ActiveContextColor") : Color.clear)
                        .frame(width: 8, height: 8)
                    Spacer()
                }
                .frame(height: 32) // Adjust to match row/icon height
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: cardScale)
        .contextMenu {
            Button("Open") {
                contextManager.openContext(contextID: context.id)
            }
            .disabled(contextManager.isActive(contextID: context.id))
            Button("Close") {
                contextManager.closeContext(contextID: context.id)
            }
            .disabled(!contextManager.isActive(contextID: context.id))
            Button("Rename") {
                draftName = context.name
                isRenaming = true
            }
            Button("Change Icon...") {
                showIconSelector = true
            }
            Divider()
            Button("Delete") {
                if context.items.isEmpty {
                    contextManager.deleteContext(contextID: context.id)
                } else {
                    showDeleteAlert = true
                }
            }
        }
        .sheet(isPresented: $showIconSelector) {
            IconSelectorView(
                selectedIconName: context.iconName,
                selectedIconBackgroundColor: context.iconBackgroundColor,
                selectedIconForegroundColor: context.iconForegroundColor,
                onSelect: { iconName, backgroundColorHex, foregroundColorHex in
                    // Update the context directly and persist
                    context.iconName = iconName
                    context.iconBackgroundColor = backgroundColorHex
                    context.iconForegroundColor = foregroundColorHex
                    contextManager.saveContexts()
                    showIconSelector = false
                },
                onCancel: {
                    showIconSelector = false
                }
            )
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Context"),
                message: Text("Are you sure you want to delete \(context.name)?"),
                primaryButton: .destructive(Text("Delete")) {
                    contextManager.deleteContext(contextID: context.id)
                },
                secondaryButton: .cancel()
            )
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                iconRotation = 360
                cardScale = 1.5
            } else {
                iconRotation = 0
                cardScale = 1.0
            }
        }
        .onChange(of: isRenaming) { _, newValue in
            if newValue {
                // ensure field gets focus when entering rename mode
                DispatchQueue.main.async { renameFieldFocused = true }
            }
        }
        .contentShape(Rectangle())
        .tag(context.id as UUID?)
        .help(analyticsTooltip(for: context.id))
    }

    private func commitRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != context.name {
            context.name = trimmed
            contextManager.saveContexts()
        }
        isRenaming = false
    }
    
    private func cancelRename() {
        draftName = context.name
        isRenaming = false
    }

    private func analyticsTooltip(for contextID: UUID) -> String {
        let analyticsManager = contextManager.analyticsManager
        let openCount = analyticsManager.getOpenCount(for: contextID)
        let lastOpen = analyticsManager.getLastOpenEvents(for: contextID).last
        let lastClose = analyticsManager.getLastCloseEvents(for: contextID).last
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .full
        var tooltip = "Opens: \(openCount)"
        if let lastOpen = lastOpen {
            tooltip += "\nLast opened: " + relativeFormatter.localizedString(for: lastOpen, relativeTo: Date())
        }
        if let lastClose = lastClose {
            tooltip += "\nLast closed: " + relativeFormatter.localizedString(for: lastClose, relativeTo: Date())
        }
        return tooltip
    }
}
