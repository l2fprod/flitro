import SwiftUI

struct SingleWindowCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            // No "New Window" or "New..." items
        }
        CommandGroup(after: .newItem) {
            Button("Open Window") {
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut("0", modifiers: [.command])
        }
    }
} 
