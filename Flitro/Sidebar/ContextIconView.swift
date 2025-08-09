import SwiftUI
import PhosphorSwift
import Foundation

struct ContextIconView: View {
    @ObservedObject var context: Context
    let size: CGFloat
    let animate: Bool
    let rotation: Double

    private var foregroundColor: Color {
        if let foregroundHex = context.iconForegroundColor, let color = Color(hex: foregroundHex) {
            return color
        } else {
            let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .teal]
            let idx = abs(context.name.hashValue) % colors.count
            return colors[idx]
        }
    }

    var body: some View {
        ZStack {
            if let backgroundColorHex = context.iconBackgroundColor, let backgroundColor = Color(hex: backgroundColorHex) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(width: size, height: size)
            }
            Group {
                if let iconName = context.iconName, let icon = Ph(rawValue: iconName) {
                    icon.regular
                        .font(.system(size: size * 0.6))
                        .foregroundColor(foregroundColor)
                } else {
                    Image(systemName: "folder")
                        .font(.system(size: size * 0.6))
                        .foregroundColor(foregroundColor)
                }
            }
            .rotationEffect(.degrees(rotation))
            .animation(animate ? .spring(response: 0.5, dampingFraction: 0.6) : nil, value: rotation)
        }
        .frame(width: size, height: size)
    }
}
