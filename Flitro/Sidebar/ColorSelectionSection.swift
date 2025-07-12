import SwiftUI

struct ColorSelectionSection: View {
    let title: String
    let colors: [Color]
    @Binding var selectedColor: Color
    @Binding var hasCustomColor: Bool
    let isBackground: Bool
    
    init(
        title: String,
        colors: [Color],
        selectedColor: Binding<Color>,
        hasCustomColor: Binding<Bool>,
        isBackground: Bool = false
    ) {
        self.title = title
        self.colors = colors
        self._selectedColor = selectedColor
        self._hasCustomColor = hasCustomColor
        self.isBackground = isBackground
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .trailing)
                .lineLimit(1)
            
            HStack(spacing: 6) {
                ForEach(colors, id: \ .self) { color in
                    Button(action: {
                        selectedColor = color
                        hasCustomColor = isBackground ? color != .clear : true
                    }) {
                        Circle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.blue : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                // Custom color option
                Button(action: {
                    let coordinator = isBackground ? BackgroundColorPanelCoordinator.shared : ForegroundColorPanelCoordinator.shared
                    coordinator.onColorChanged = { color in
                        selectedColor = color
                        hasCustomColor = true
                    }
                    coordinator.showColorPanel(initialColor: selectedColor)
                }) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
} 