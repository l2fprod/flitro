import SwiftUI
import AppKit

struct ContextTitleView: View {
    @ObservedObject var context: Context
    @ObservedObject var contextManager: ContextManager

    @State private var isEditingTitle = false
    @State private var draftTitle = ""
    @State private var isHoveringTitle = false
    @FocusState private var titleFieldFocused: Bool
    // Freeze font size while editing to avoid per-keystroke layout changes
    @State private var editingFontSize: CGFloat = 17
    // Capture displayed width and freeze it during edit to avoid overflow and layout jumps
    @State private var displayWidth: CGFloat = 0
    @State private var editingWidth: CGFloat? = nil

    // Force toolbar relayout when the context or title size category changes
    private var principalLayoutID: String {
        if isEditingTitle {
            // Important: do not depend on draftTitle length while editing to avoid TextField resets
            return "\(context.id)-e"
        } else {
            let bucket = max(1, min(8, context.name.count / 12)) // coarse buckets to reduce churn
            return "\(context.id)-v-\(bucket)"
        }
    }

    // Adaptive font for display state only (no per-keystroke changes)
    private var displayTitleFont: Font {
        let size: CGFloat = context.name.count > 30 ? 15 : 17
        return .system(size: size, weight: .bold)
    }
    // Editing font uses a frozen size captured on edit begin
    private var editingTitleFont: Font {
        .system(size: editingFontSize, weight: .bold)
    }

    var body: some View {
        Group {
            if isEditingTitle {
                HStack(spacing: 8) {
                    TextField("Context Name", text: $draftTitle, onCommit: { commitTitle() })
                        .font(editingTitleFont)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($titleFieldFocused)
                        .onAppear {
                            // Focus the field when entering edit mode; draftTitle is set when toggling edit mode
                            DispatchQueue.main.async { self.titleFieldFocused = true }
                        }
                        .onExitCommand { cancelEditTitle() }
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                    // Quick actions for explicit save/cancel
                    Button { commitTitle() } label: {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Save title")
                    Button { cancelEditTitle() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel editing")
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                )
                // Allow the title editor to expand across available toolbar space (baseline)
                .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                // Freeze width to what was available at the start of editing (must be last)
                .frame(width: editingWidth, alignment: .leading)
                // Disable implicit animations tied to typing to prevent wiggle
                .animation(nil, value: draftTitle)
                // Keep stable id logic
                .id(principalLayoutID)
            } else {
                HStack(spacing: 6) {
                    Text(context.name)
                        .font(displayTitleFont)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            draftTitle = context.name
                            // Capture font size and available width once for the edit session
                            editingFontSize = (context.name.count > 30 ? 15 : 17)
                            editingWidth = max(140, displayWidth)
                            isEditingTitle = true
                        }
                    // Reserve space for the pencil to avoid layout shifts and only fade it
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .opacity(isHoveringTitle ? 1 : 0)
                        .frame(width: 16, height: 16)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHoveringTitle ? Color.accentColor.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isHoveringTitle ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
                )
                // Allow the title to expand across available toolbar space
                .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                // Continuously capture laid-out width of the display state
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: TitleWidthKey.self, value: proxy.size.width)
                    }
                )
                .onPreferenceChange(TitleWidthKey.self) { width in
                    displayWidth = width
                }
                .onHover { hovering in
                    isHoveringTitle = hovering
                }
                .help("Click to rename")
                .id(principalLayoutID)
            }
        }
        .onChange(of: context.id) { _, _ in
            isEditingTitle = false
            draftTitle = context.name
            editingWidth = nil
        }
        .onChange(of: isEditingTitle) { _, newValue in
            if newValue {
                // Ensure editing font is frozen even when entering edit via keyboard
                editingFontSize = (context.name.count > 30 ? 15 : 17)
            } else {
                // Reset width constraint when leaving edit mode
                editingWidth = nil
            }
        }
    }

    // MARK: - Title helpers
    private func commitTitle() {
        isEditingTitle = false
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != context.name {
            context.name = trimmed
            contextManager.saveContexts()
        } else {
            // Restore draft to the current name if unchanged
            draftTitle = context.name
        }
    }

    private func cancelEditTitle() {
        draftTitle = context.name
        isEditingTitle = false
        editingWidth = nil
    }
}

// Preference key for capturing the laid-out width of the title area in display mode
private struct TitleWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
