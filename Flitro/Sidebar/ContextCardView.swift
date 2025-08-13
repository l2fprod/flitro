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

    private var itemCountText: String {
        let total = context.items.count
        return "\(total) items"
    }
    
    private var isActive: Bool {
        contextManager.isActive(contextID: context.id)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ContextIconView(
                context: context,
                size: 32,
                animate: true,
                rotation: iconRotation
            )
            .scaleEffect(cardScale)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.name)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.6)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(itemCountText)
                    .font(.footnote)
            }
            // // Dot indicator at top right
            VStack(alignment: .trailing, spacing: 0) {
                Circle()
                    .fill(isActive ? Color("ActiveContextColor") : Color.clear)
                    .frame(width: 8, height: 8)
                Spacer()
            }
            .frame(height: 32) // Adjust to match row/icon height
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
        .contentShape(Rectangle())
        .tag(context.id as UUID?)
        .help(analyticsTooltip(for: context.id))
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
