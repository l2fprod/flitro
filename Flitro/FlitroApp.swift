import SwiftUI
import AppKit
import PhosphorSwift
import Sparkle

// MARK: - App Delegate for Window Reopen and Hide-on-Close
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var updaterController: SPUStandardUpdaterController?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Find the main window (not status bar windows) to set as delegate
        if let window = NSApp.windows.first(where: {
            String(describing: type(of: $0)) != "NSStatusBarWindow" &&
            $0.level == .normal
        }) {
            window.delegate = self
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil) // Hides the window instead of closing
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        // Handle Core Spotlight context activation
        if userActivity.activityType == "com.apple.corespotlightitem",
           let contextIDString = userActivity.userInfo?["kCSSearchableItemActivityIdentifier"] as? String,
           let contextID = UUID(uuidString: contextIDString) {
            print("[AppDelegate] Toggling context from Core Spotlight: \(contextID)")
            if ContextManager.shared.isActive(contextID: contextID) {
                ContextManager.shared.closeContext(contextID: contextID)
            } else {
                ContextManager.shared.switchToContext(contextID: contextID)
            }
            return true
        }
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

    init() {
        // Ensure updaterController is initialized before any scene
        if appDelegate.updaterController == nil {
            appDelegate.updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Flitro") {
                    openWindow(id: "about")
                }
                Button("Check for Updates...") {
                    if let updater = appDelegate.updaterController?.updater {
                        updater.checkForUpdates()
                    }
                }
            }
            SingleWindowCommands()
        }
        MenuBarExtra("Flitro", systemImage: "rectangle.3.offgrid") {
            MenuBarExtraContents(updater: appDelegate.updaterController?.updater)
                .environmentObject(ContextManager.shared)
        }
        Settings {
            if let updater = appDelegate.updaterController?.updater {
                SettingsView(updater: updater)
            } else {
                Text("Updater not available")
            }
        }
        WindowGroup("About Flitro", id: "about") {
            AboutView()
                .frame(width: 360, height: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

    @Environment(\.openWindow) var openWindow
}

func showMainWindow() {
    // First activate the app to ensure it can receive focus
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    // Find the main window (not status bar windows)
    if let window = NSApp.windows.first(where: {
        String(describing: type(of: $0)) != "NSStatusBarWindow" &&
        $0.level == .normal
    }) {
        if !window.isVisible {
            window.orderFrontRegardless()
        }
        window.makeKeyAndOrderFront(nil)
    }
}

struct SingleWindowCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            // No "New Window" or "New..." items
        }
        CommandGroup(after: .newItem) {
            Button("Open Window") {
                showMainWindow()
            }
            .keyboardShortcut("0", modifiers: [.command])
        }
    }
}

struct MenuBarExtraContents: View {
    @EnvironmentObject var contextManager: ContextManager
    @Environment(\.openSettings) private var openSettings
    let updater: SPUUpdater?

    var body: some View {
        ForEach(contextManager.contexts, id: \.reactiveId) { context in
            Menu {
                Button("Open") {
                    contextManager.switchToContext(contextID: context.id)
                }
                Divider()
                Button("Close") {
                    contextManager.closeContext(contextID: context.id)
                }
            } label: {
                HStack {
                    if let iconName = context.iconName, let icon = Ph(rawValue: iconName) {
                        icon.regular
                            .font(.system(size: 20))
                    } else {
                        Image(systemName: "folder")
                            .font(.system(size: 20))
                    }
                    Text(context.name)
                }
            }
        }
        if !contextManager.contexts.isEmpty {
            Divider()
        }
        Button("Show Flitro") {
            showMainWindow()
        }
        Divider()
        Button("Check for Updates...") {
            updater?.checkForUpdates()
        }
        Button("Settings") {
            openSettings()
        }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
    }
}
