import SwiftUI
import AppKit

class ColorPanelCoordinator: NSObject {
    var onColorChanged: ((Color) -> Void)?
    private var colorPanel: NSColorPanel?
    
    func showColorPanel(initialColor: Color) {
        colorPanel = NSColorPanel()
        colorPanel?.color = NSColor(initialColor)
        colorPanel?.setTarget(self)
        colorPanel?.setAction(#selector(colorChanged))
        colorPanel?.makeKeyAndOrderFront(nil)
    }
    
    @objc func colorChanged() {
        guard let colorPanel = colorPanel else { return }
        let newColor = Color(colorPanel.color)
        onColorChanged?(newColor)
    }
    
    func closeColorPanel() {
        colorPanel?.close()
        colorPanel = nil
    }
} 