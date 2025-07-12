import SwiftUI
import Foundation
import PhosphorSwift

struct IconSelectorView: View {
    let selectedIconName: String?
    let selectedIconBackgroundColor: String?
    let selectedIconForegroundColor: String?
    let onSelect: (String?, String?, String?) -> Void
    let onCancel: () -> Void
    
    @State private var searchText = ""
    @State private var selectedIcon: String?
    @State private var selectedBackgroundColor: Color = .clear
    @State private var selectedForegroundColor: Color = .black
    @State private var hasCustomBackgroundColor: Bool = false
    @State private var hasCustomForegroundColor: Bool = false
    
    // Predefined colors
    private let pastelColors: [Color] = [
        Color(red: 1.0, green: 0.8, blue: 0.8), // Light pink
        Color(red: 1.0, green: 0.6, blue: 0.8), // Pink
        Color(red: 0.9, green: 0.7, blue: 1.0), // Light purple
        Color(red: 0.8, green: 0.8, blue: 1.0), // Light blue
        Color(red: 0.7, green: 0.8, blue: 1.0), // Sky blue
        Color(red: 0.8, green: 1.0, blue: 1.0), // Light cyan
        Color(red: 0.8, green: 1.0, blue: 0.8), // Light green
        Color(red: 1.0, green: 1.0, blue: 0.8), // Light yellow
        Color(red: 1.0, green: 0.9, blue: 0.8), // Peach
        Color(red: 1.0, green: 0.7, blue: 0.7), // Light red
        Color(red: 1.0, green: 0.8, blue: 0.9), // Rose
        Color(red: 0.9, green: 0.8, blue: 0.9), // Lavender
        Color(red: 0.8, green: 0.9, blue: 0.9), // Mint
        Color(red: 0.9, green: 0.9, blue: 0.8), // Cream
        Color(red: 0.8, green: 0.8, blue: 0.9), // Periwinkle
        Color(red: 0.9, green: 0.8, blue: 0.8), // Salmon
        Color(red: 0.9, green: 0.9, blue: 0.9)  // Light gray
    ]
    
    private let foregroundColors: [Color] = [
        .black,    // Black
        .white,    // White
        Color(red: 0.2, green: 0.2, blue: 0.2), // Dark gray
        Color(red: 0.8, green: 0.8, blue: 0.8), // Light gray
        Color(red: 0.8, green: 0.2, blue: 0.2), // Dark red
        Color(red: 0.2, green: 0.6, blue: 0.2), // Dark green
        Color(red: 0.2, green: 0.2, blue: 0.8), // Dark blue
        Color(red: 0.6, green: 0.2, blue: 0.8), // Purple
        Color(red: 0.8, green: 0.6, blue: 0.2), // Orange
        Color(red: 0.8, green: 0.2, blue: 0.6), // Magenta
        Color(red: 0.2, green: 0.8, blue: 0.8), // Teal
        Color(red: 0.6, green: 0.8, blue: 0.2), // Lime
        Color(red: 0.8, green: 0.8, blue: 0.2), // Yellow
        Color(red: 0.4, green: 0.4, blue: 0.4), // Medium gray
        Color(red: 0.6, green: 0.6, blue: 0.6), // Light gray
        Color(red: 0.9, green: 0.9, blue: 0.9), // Very light gray
        Color(red: 0.1, green: 0.1, blue: 0.1)  // Very dark gray
    ]
    
    private var filteredIcons: [String] {
        if searchText.isEmpty {
            return Ph.allCases.map { $0.rawValue }
        } else {
            return Ph.allCases
                .map { $0.rawValue }
                .filter { $0.localizedCaseInsensitiveContains(searchText) }
                .map { $0 }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search icons...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                Spacer()
                Text("\(filteredIcons.count) icons")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
            
            // Icon grid
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                        // Default icon
                        IconGridItem(
                            iconName: nil,
                            isSelected: selectedIcon == nil,
                            hasCustomBackgroundColor: hasCustomBackgroundColor,
                            selectedBackgroundColor: selectedBackgroundColor,
                            hasCustomForegroundColor: hasCustomForegroundColor,
                            selectedForegroundColor: selectedForegroundColor,
                            onTap: { selectedIcon = nil }
                        )
                        .id("default")
                        
                        // Icon options
                        ForEach(filteredIcons, id: \ .self) { iconName in
                            IconGridItem(
                                iconName: iconName,
                                isSelected: selectedIcon == iconName,
                                hasCustomBackgroundColor: hasCustomBackgroundColor,
                                selectedBackgroundColor: selectedBackgroundColor,
                                hasCustomForegroundColor: hasCustomForegroundColor,
                                selectedForegroundColor: selectedForegroundColor,
                                onTap: { selectedIcon = iconName }
                            )
                            .id(iconName)
                        }
                    }
                    .padding(20)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let selectedIconName = selectedIconName {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(selectedIconName, anchor: .center)
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("default", anchor: .center)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Color selection sections
            ColorSelectionSection(
                title: "Foreground:",
                colors: foregroundColors,
                selectedColor: $selectedForegroundColor,
                hasCustomColor: $hasCustomForegroundColor
            )
            
            Divider()
            
            ColorSelectionSection(
                title: "Background:",
                colors: pastelColors,
                selectedColor: $selectedBackgroundColor,
                hasCustomColor: $hasCustomBackgroundColor,
                isBackground: true
            )
            
            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Select") {
                    let backgroundHex = hasCustomBackgroundColor ? selectedBackgroundColor.toHexString() : nil
                    let foregroundHex = hasCustomForegroundColor ? selectedForegroundColor.toHexString() : nil
                    onSelect(selectedIcon, backgroundHex, foregroundHex)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIcon == selectedIconName && 
                         (!hasCustomBackgroundColor || selectedBackgroundColor.toHexString() == selectedIconBackgroundColor) &&
                         (!hasCustomForegroundColor || selectedForegroundColor.toHexString() == selectedIconForegroundColor))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 700, height: 540)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            selectedIcon = selectedIconName
            if let hex = selectedIconBackgroundColor, let color = Color(hex: hex) {
                selectedBackgroundColor = color
                hasCustomBackgroundColor = true
            } else {
                selectedBackgroundColor = .clear
                hasCustomBackgroundColor = false
            }
            
            if let hex = selectedIconForegroundColor, let color = Color(hex: hex) {
                selectedForegroundColor = color
                hasCustomForegroundColor = true
            } else {
                selectedForegroundColor = .black
                hasCustomForegroundColor = false
            }
        }
        .onChange(of: selectedBackgroundColor) { _, newColor in
            hasCustomBackgroundColor = newColor != .clear
        }
    }
} 