import SwiftUI
import AppKit

// MARK: - App Delegate for Window Reopen and Hide-on-Close
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window = sender.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
        }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApp.windows.first {
            window.delegate = self
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil) // Hides the window instead of closing
        NSApp.setActivationPolicy(.accessory)
        return false
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var contextManager = ContextManager.shared
    @State private var selectedContextID: UUID? = nil
    
    var selectedContext: Context? {
        contextManager.contexts.first(where: { $0.id == selectedContextID })
    }
    
    var body: some View {
        ContextEditorView(
            contextManager: contextManager,
            selectedContextID: $selectedContextID
        )
        .onAppear {
            if selectedContextID == nil, let first = contextManager.contexts.first {
                selectedContextID = first.id
            }
        }
    }
}

// MARK: - App Entry Point
@main
struct FlitroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .commands {
            SingleWindowCommands()
        }
        MenuBarExtra("Flitro", systemImage: "rectangle.3.offgrid") {
            MenuBarExtraContents().environmentObject(ContextManager.shared)
        }
    }
}

struct MenuBarExtraContents: View {
    @EnvironmentObject var contextManager: ContextManager

    var body: some View {
        Button("Configure") {
            // First activate the app to ensure it can receive focus
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            // Then bring the window to front
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
        Divider()
        ForEach(contextManager.contexts) { context in
            Menu(context.name) {
                ForEach(SwitchingMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue) {
                        contextManager.switchToContext(context, switchingMode: mode)
                    }
                }
                Divider()
                Button("Close") {
                    contextManager.closeContextApplications(context)
                }
            }
        }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
    }
}
