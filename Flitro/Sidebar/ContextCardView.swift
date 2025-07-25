import SwiftUI
import PhosphorSwift
import Foundation

// MARK: - Context Card View

struct ContextCardView: View {
    let context: Context
    let isSelected: Bool
    let onIconChange: (String?, String?, String?) -> Void
    
    @State private var showIconSelector = false
    @State private var iconRotation: Double = 0
    @State private var cardScale: CGFloat = 1.0
    @EnvironmentObject private var contextManager: ContextManager
    
    private var iconColor: Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .teal]
        let idx = abs(context.name.hashValue) % colors.count
        return colors[idx]
    }
    
    private var foregroundColor: Color {
        if let foregroundHex = context.iconForegroundColor, let color = Color(hex: foregroundHex) {
            return color
        } else {
            return iconColor
        }
    }
    
    private var itemCountText: String {
        let total = context.items.count
        return "\(total) items"
    }
    
    private var isActive: Bool {
        contextManager.isActive(contextID: context.id)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon
            Group {
                ZStack {
                    if let backgroundColorHex = context.iconBackgroundColor, let backgroundColor = Color(hex: backgroundColorHex) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(backgroundColor)
                            .frame(width: 32, height: 32)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .frame(width: 32, height: 32)
                    }
                    Group {
                        if let iconName = context.iconName, let icon = Ph(rawValue: iconName) {
                            icon.regular
                                .font(.title2)
                                .foregroundColor(foregroundColor)
                        } else {
                            Image(systemName: "folder")
                                .font(.title2)
                                .foregroundColor(foregroundColor)
                        }
                    }
                    .rotationEffect(.degrees(iconRotation))
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: iconRotation)
                }
            }
            .frame(width: 32, height: 32)

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
                contextManager.switchToContext(contextID: context.id)
            }
            .disabled(contextManager.isActive(contextID: context.id))
            Button("Close") {
                contextManager.closeContext(contextID: context.id)
            }
            .disabled(!contextManager.isActive(contextID: context.id))
            Button("Change Icon...") {
                showIconSelector = true
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
        .onAppear {
            iconRotation = isActive ? 360 : 0
            cardScale = isActive ? 1.04 : 1.0
        }
        .onChange(of: isActive) { active, _ in
            if active {
                iconRotation = 360
                cardScale = 1.04
            } else {
                iconRotation = 0
                cardScale = 1.0
            }
        }
    }
}
