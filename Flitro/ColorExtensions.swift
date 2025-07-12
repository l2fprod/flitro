import SwiftUI

// MARK: - Color <-> Hex helpers
extension Color {
    init?(hex: String) {
        var hex = hex
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let intVal = Int(hex, radix: 16) else { return nil }
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
    
    func toHexString() -> String? {
        let uiColor = NSColor(self)
        guard let rgb = uiColor.usingColorSpace(.deviceRGB) else { return nil }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    // Returns a lighter version of the color by blending with white
    func lighter(by amount: CGFloat = 0.6) -> Color {
        let uiColor = NSColor(self)
        guard let rgb = uiColor.usingColorSpace(.deviceRGB) else { return self }
        let r = rgb.redComponent + (1.0 - rgb.redComponent) * amount
        let g = rgb.greenComponent + (1.0 - rgb.greenComponent) * amount
        let b = rgb.blueComponent + (1.0 - rgb.blueComponent) * amount
        return Color(red: r, green: g, blue: b)
    }
    
    // Returns a darker version of the color by blending with black
    func darker(by amount: CGFloat = 0.3) -> Color {
        let uiColor = NSColor(self)
        guard let rgb = uiColor.usingColorSpace(.deviceRGB) else { return self }
        let r = rgb.redComponent * (1.0 - amount)
        let g = rgb.greenComponent * (1.0 - amount)
        let b = rgb.blueComponent * (1.0 - amount)
        return Color(red: r, green: g, blue: b)
    }

    // Returns the contrast ratio between self and another color (WCAG 2.0)
    func contrastRatio(with other: Color) -> CGFloat {
        let c1 = NSColor(self).usingColorSpace(.deviceRGB) ?? .black
        let c2 = NSColor(other).usingColorSpace(.deviceRGB) ?? .white
        func luminance(_ c: NSColor) -> CGFloat {
            func channel(_ v: CGFloat) -> CGFloat {
                return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(c.redComponent) + 0.7152 * channel(c.greenComponent) + 0.0722 * channel(c.blueComponent)
        }
        let l1 = luminance(c1)
        let l2 = luminance(c2)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
} 