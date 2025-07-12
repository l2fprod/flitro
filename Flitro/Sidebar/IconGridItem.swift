import SwiftUI
import PhosphorSwift

struct IconGridItem: View {
    let iconName: String?
    let isSelected: Bool
    let hasCustomBackgroundColor: Bool
    let selectedBackgroundColor: Color
    let hasCustomForegroundColor: Bool
    let selectedForegroundColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    if hasCustomBackgroundColor {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedBackgroundColor)
                            .frame(width: 40, height: 40)
                    }
                    if let iconName = iconName, let icon = Ph(rawValue: iconName) {
                        icon.regular
                            .font(.title2)
                            .foregroundColor(hasCustomForegroundColor ? selectedForegroundColor : .primary)
                    } else {
                        Image(systemName: "folder")
                            .font(.title2)
                            .foregroundColor(hasCustomForegroundColor ? selectedForegroundColor : .blue)
                    }
                }
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
            }
        }
        .buttonStyle(.plain)
    }
} 