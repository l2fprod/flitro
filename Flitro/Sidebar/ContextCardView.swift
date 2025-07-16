import SwiftUI
import PhosphorSwift
import Foundation

// MARK: - Context Card View

struct ContextCardView: View {
    let context: Context
    let isSelected: Bool
    let onSelect: () -> Void
    let onIconChange: (String?, String?, String?) -> Void
    
    @State private var isHovered = false
    @State private var showIconSelector = false
    
    var iconColor: Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .teal]
        let idx = abs(context.name.hashValue) % colors.count
        return colors[idx]
    }
    
    var foregroundColor: Color {
        if let foregroundHex = context.iconForegroundColor, let color = Color(hex: foregroundHex) {
            return color
        } else {
            return iconColor
        }
    }
    
    var itemCountText: String {
        let total = context.applications.count + context.documents.count + context.browserTabs.count + context.terminalSessions.count
        return "\(total) items"
    }
    
    var backgroundColor: Color {
        if isSelected {
            if let backgroundColorHex = context.iconBackgroundColor, let backgroundColor = Color(hex: backgroundColorHex) {
                return backgroundColor.darker(by: 0.25)
            } else {
                return Color.accentColor.opacity(0.32)
            }
        } else if isHovered {
            return Color.accentColor.opacity(0.12)
        } else {
            return Color.clear
        }
    }

    // Adaptive label color for best contrast
    var adaptiveLabelColor: Color {
        let bg: Color = backgroundColor
        // Try icon foreground color if set and not too close to background
        if let foregroundHex = context.iconForegroundColor, let fg = Color(hex: foregroundHex), fg.contrastRatio(with: bg) > 2.5, fg != bg {
            return fg
        }
        // Otherwise, pick black or white for best contrast
        let blackContrast = Color.black.contrastRatio(with: bg)
        let whiteContrast = Color.white.contrastRatio(with: bg)
        return blackContrast > whiteContrast ? .black : .white
    }
    
    var borderColor: Color {
        isSelected ? Color.accentColor : Color(NSColor.separatorColor)
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
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.name)
                    .font(.system(size: 16, weight: .semibold))
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture { onSelect() }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
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
    }
} 