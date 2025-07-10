import SwiftUI

struct SingleWindowCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            // No "New Window" or "New..." items
        }
        CommandGroup(after: .newItem) {
            Button("Open Window") {
                // First activate the app to ensure it can receive focus
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)

                // Then bring the window to front
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
            .keyboardShortcut("0", modifiers: [.command])
        }
    }
} 
