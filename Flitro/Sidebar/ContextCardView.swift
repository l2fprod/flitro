import SwiftUI
import PhosphorSwift
import Foundation

// MARK: - Context Card View

struct ContextCardView: View {
    @ObservedObject var context: Context
    let isSelected: Bool
    let onIconChange: (String?, String?, String?) -> Void
    let onDeleteRequest: (() -> Void)? // Optional handler for delete request
    
    @State private var showIconSelector = false
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
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scaleEffect(cardScale)
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
                onDeleteRequest?() // Use handler if provided
            }
        }
        .sheet(isPresented: $showIconSelector) {
            IconSelectorView(
                selectedIconName: context.iconName,
                selectedIconBackgroundColor: context.iconBackgroundColor,
                selectedIconForegroundColor: context.iconForegroundColor,
                onSelect: { iconName, backgroundColorHex, foregroundColorHex in
                    onIconChange(iconName, backgroundColorHex, foregroundColorHex)
                    showIconSelector = false
                },
                onCancel: {
                    showIconSelector = false
                }
            )
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                iconRotation = 360
                cardScale = 1.04
            } else {
                iconRotation = 0
                cardScale = 1.0
            }
        }
    }
}
