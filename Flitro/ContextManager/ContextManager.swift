import Foundation
import AppKit
import ApplicationServices

// MARK: - Data Models

enum ContextItem: Codable, Equatable, Hashable {
    case application(AppItem)
    case document(DocumentItem)
    case browserTab(BrowserTab)
    case terminalSession(TerminalSession)

    enum CodingKeys: String, CodingKey {
        case type, value
    }
    enum ItemType: String, Codable {
        case application, document, browserTab, terminalSession
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        switch type {
        case .application:
            self = .application(try container.decode(AppItem.self, forKey: .value))
        case .document:
            self = .document(try container.decode(DocumentItem.self, forKey: .value))
        case .browserTab:
            self = .browserTab(try container.decode(BrowserTab.self, forKey: .value))
        case .terminalSession:
            self = .terminalSession(try container.decode(TerminalSession.self, forKey: .value))
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .application(let app):
            try container.encode(ItemType.application, forKey: .type)
            try container.encode(app, forKey: .value)
        case .document(let doc):
            try container.encode(ItemType.document, forKey: .type)
            try container.encode(doc, forKey: .value)
        case .browserTab(let tab):
            try container.encode(ItemType.browserTab, forKey: .type)
            try container.encode(tab, forKey: .value)
        case .terminalSession(let session):
            try container.encode(ItemType.terminalSession, forKey: .type)
            try container.encode(session, forKey: .value)
        }
    }
}

struct Context: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    private(set) var items: [ContextItem]
    var iconName: String? = nil
    var iconBackgroundColor: String? = nil // Optional hex color string
    var iconForegroundColor: String? = nil // Optional hex color string
    var createdAt: Date = Date()
    var lastUsed: Date = Date()
    
    /// Changes when any property relevant to UI changes.
    var reactiveId: Int {
        var hasher = Hasher()
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(iconName)
        hasher.combine(iconBackgroundColor)
        hasher.combine(iconForegroundColor)
        hasher.combine(items.count)
        // Add more properties as needed for UI reactivity
        return hasher.finalize()
    }
    
    static func == (lhs: Context, rhs: Context) -> Bool {
        lhs.id == rhs.id
    }

    // Mutating item methods
    mutating func addItem(_ item: ContextItem) {
        items.append(item)
    }
    mutating func removeItem(at index: Int) {
        items.remove(at: index)
    }
    mutating func moveItems(fromOffsets: IndexSet, toOffset: Int) {
        items.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }
}

struct AppItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var bundleIdentifier: String
    var windowTitle: String?
    var filePath: String?
}

struct DocumentItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var filePath: String
    var application: String
    var bookmark: Data? = nil // Security-scoped bookmark
}

struct BrowserTab: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String
    var url: String
    var browser: String // Safari, Chrome, Firefox
}

struct TerminalSession: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var workingDirectory: String
    var command: String?
    var title: String
}

// MARK: - Context Manager

class ContextManager: ObservableObject {
    static let shared = ContextManager()
    @Published var contexts: [Context] = []
    @Published var activeContexts: [Context] = []
    
    // Store launchers per context
    private var contextLaunchers: [UUID: [ContextApplicationLauncher]] = [:]
    
    // Restore missing file URL properties for persistence
    private let appName = Bundle.main.bundleIdentifier ?? "Flitro"
    private let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    private var appDirectory: URL {
        let dir = appSupportURL.appendingPathComponent(appName, isDirectory: true)
        // Ensure the directory exists
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }
    private var contextsFileURL: URL {
        appDirectory.appendingPathComponent("contexts.json")
    }
    
    /// Helper to get the bundle identifier of the system default browser
    private func getDefaultBrowserBundleId() -> String? {
        let workspace = NSWorkspace.shared
        guard let httpURL = URL(string: "http://example.com") else {
            return nil
        }
        if let appURL = workspace.urlForApplication(toOpen: httpURL) {
            return Bundle(url: appURL)?.bundleIdentifier
        }
        return nil
    }

    init() {
        loadContexts()
    }
    
    // MARK: - Context Management
    
    func addContext(_ context: Context) {
        contexts.append(context)
        saveContexts()
    }
  
    func deleteContext(contextID: UUID) {
        contexts.removeAll { $0.id == contextID }
        activeContexts.removeAll { $0.id == contextID }
        contextLaunchers.removeValue(forKey: contextID)
        saveContexts()
    }
    
    // MARK: - Context Switching
    
    func switchToContext(contextID: UUID) {
        guard let latestContext = contexts.first(where: { $0.id == contextID }) else { return }
        activeContexts.append(latestContext)
        openContext(contextID: contextID)
        saveContexts()
    }

    /// Determine the bundle identifier for a ContextItem
    private func bundleId(for item: ContextItem) -> String? {
        switch item {
        case .application(let app):
            return app.bundleIdentifier
        case .document(let doc):
            if !doc.application.isEmpty {
                return doc.application
            } else {
                // Lookup default app for this file
                let url = URL(fileURLWithPath: doc.filePath)
                if let appURL = NSWorkspace.shared.urlForApplication(toOpen: url),
                   let bundleId = Bundle(url: appURL)?.bundleIdentifier {
                    return bundleId
                } else {
                    return nil
                }
            }
        case .browserTab(let tab):
            switch tab.browser.lowercased() {
            case "chrome": return "com.google.Chrome"
            case "safari": return "com.apple.Safari"
            case "firefox": return "org.mozilla.firefox"
            case "default", "":
                return getDefaultBrowserBundleId()
            default: return nil
            }
        case .terminalSession:
            return nil
        }
    }

    /// Create the appropriate launcher for a given bundleId and items
    private func launcher(for bundleId: String, items: [ContextItem]) -> ContextApplicationLauncher {
        switch bundleId {
        case "com.google.Chrome":
            return ChromeApplicationLauncher(items: items)
        case "com.apple.Safari":
            return SafariApplicationLauncher(items: items)
        case "org.mozilla.firefox":
            return FirefoxApplicationLauncher(items: items)
        case "com.apple.Preview":
            return PreviewApplicationLauncher(items: items)
        default:
            return DefaultApplicationLauncher(bundleIdentifier: bundleId, items: items)
        }
    }

    /// Open all items in the context, batching by app/bundle where possible, using launchers
    private func openContext(contextID: UUID) {
        guard let contextToOpen = contexts.first(where: { $0.id == contextID }) else { return }
        print("🚀 Opening context '\(contextToOpen.name)' with \(contextToOpen.items.count) items")

        var itemsByBundle: [String: [ContextItem]] = [:]
        for item in contextToOpen.items {
            if let bundleId = bundleId(for: item) {
                itemsByBundle[bundleId, default: []].append(item)
            }
        }

        var launchers: [ContextApplicationLauncher] = []
        for (bundleId, items) in itemsByBundle {
            let launcher = launcher(for: bundleId, items: items)

            // Trace which launcher is opening which items
            let launcherType = String(describing: type(of: launcher))
            print("📱 Using \(launcherType) for bundle '\(bundleId)' with \(items.count) items:")

            for item in items {
                switch item {
                case .application(let app):
                    print("   • App: \(app.name) (\(app.bundleIdentifier))")
                    if let windowTitle = app.windowTitle {
                        print("     Window: \(windowTitle)")
                    }
                    if let filePath = app.filePath {
                        print("     File: \(filePath)")
                    }
                case .document(let doc):
                    print("   • Document: \(doc.name) at \(doc.filePath)")
                case .browserTab(let tab):
                    print("   • Browser Tab: \(tab.title) - \(tab.url)")
                case .terminalSession(let session):
                    print("   • Terminal Session: \(session.title) in \(session.workingDirectory)")
                    if let command = session.command {
                        print("     Command: \(command)")
                    }
                }
            }

            launcher.open()
            launchers.append(launcher)
        }

        // Store launchers for this context
        contextLaunchers[contextToOpen.id] = launchers

        // Open terminal sessions directly (not via launcher abstraction)
        let terminalSessions = contextToOpen.items.compactMap { item -> TerminalSession? in
            if case .terminalSession(let session) = item { return session } else { return nil }
        }

        if !terminalSessions.isEmpty {
            print("🖥️  Opening \(terminalSessions.count) terminal session(s) directly:")
        }

        for item in contextToOpen.items {
            if case .terminalSession(let session) = item {
                let commandToRun: String
                if let command = session.command, !command.isEmpty {
                    commandToRun = command
                } else {
                    print("   ⚠️  Skipping terminal session '\(session.title)' - no command specified")
                    continue // Skip if no command
                }
                let workingDir = session.workingDirectory
                print("   • Terminal: '\(session.title)' in '\(workingDir)' running '\(commandToRun)'")

                let script = """
                tell application \"Terminal\"
                    activate
                    do script \"cd \" & quoted form of \"\(workingDir)\" & \\"; \(commandToRun)\"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary? = nil
                    appleScript.executeAndReturnError(&error)
                    if let error = error {
                        print("     ❌ Failed to launch terminal session: \(error)")
                    } else {
                        print("     ✅ Terminal session launched successfully")
                    }
                }
            }
        }

        print("✅ Context '\(contextToOpen.name)' opened with \(launchers.count) launcher(s) and \(terminalSessions.count) terminal session(s)")
    }
    
    // MARK: - Context Reordering
    /// Reorder contexts and persist the new order
    func reorderContexts(fromOffsets: IndexSet, toOffset: Int) {
        contexts.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveContexts()
    }
    
    // MARK: - Application Management
    
    func closeContext(contextID: UUID) {
        if let launchers = contextLaunchers[contextID] {
            for launcher in launchers {
                launcher.close()
            }
            contextLaunchers.removeValue(forKey: contextID)
        }
        activeContexts.removeAll { $0.id == contextID }
    }

    func closeAllContexts() {
        // Close all active contexts
        for context in activeContexts {
            if let launchers = contextLaunchers[context.id] {
                for launcher in launchers {
                    launcher.close()
                }
                contextLaunchers.removeValue(forKey: context.id)
            }
        }
        activeContexts.removeAll()
    }
    
    // MARK: - Persistence
    
    func saveContexts() {
        do {
            print("Saving contexts to \(contextsFileURL)")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(contexts)
            try data.write(to: contextsFileURL)
        } catch {
            print("Failed to save contexts: \(error)")
        }
    }
    
    private func loadContexts() {
        do {
            let data = try Data(contentsOf: contextsFileURL)
            // Try decoding as new format
            let decoded = try JSONDecoder().decode([Context].self, from: data)
            self.contexts = decoded
        } catch {
            print("No existing contexts.json found or failed to read: \(error)")
        }
    }

    /// Returns the best icon for a given ContextItem (app, document, browser tab, etc.)
    public func icon(for item: ContextItem) -> NSImage? {
        let ws = NSWorkspace.shared
        if let bundleId = bundleId(for: item),
           let url = ws.urlForApplication(withBundleIdentifier: bundleId) {
            return ws.icon(forFile: url.path)
        }
        return nil
    }

    func isActive(contextID: UUID) -> Bool {
        return activeContexts.contains(where: { $0.id == contextID })
    }
}

extension ContextManager {
    func openItem(_ item: ContextItem) {
        if let bundleId = bundleId(for: item) {
            let launcher = launcher(for: bundleId, items: [item])
            launcher.open()
        } else if case .terminalSession(let session) = item {
            // Implement if you want to support single terminal session open
            let commandToRun: String
            if let command = session.command, !command.isEmpty {
                commandToRun = command
            } else {
                return // Skip if no command
            }
            let workingDir = session.workingDirectory
            let script = """
            tell application \"Terminal\"
                activate
                do script \"cd \" & quoted form of \"\(workingDir)\" & \\"; \(commandToRun)\"
            end tell
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary? = nil
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("Failed to launch terminal session: \(error)")
                }
            }
        }
    }
} 

extension ContextManager {
    func addItem(_ item: ContextItem, to contextID: UUID) {
        guard let idx = contexts.firstIndex(where: { $0.id == contextID }) else { return }
        contexts[idx].addItem(item)
        saveContexts()
    }
    func removeItem(at itemIndex: Int, from contextID: UUID) {
        guard let idx = contexts.firstIndex(where: { $0.id == contextID }) else { return }
        contexts[idx].removeItem(at: itemIndex)
        saveContexts()
    }
    func moveItems(fromOffsets: IndexSet, toOffset: Int, in contextID: UUID) {
        guard let idx = contexts.firstIndex(where: { $0.id == contextID }) else { return }
        contexts[idx].moveItems(fromOffsets: fromOffsets, toOffset: toOffset)
        saveContexts()
    }
}

// Helper to move elements in array
extension Array {
    mutating func move(fromOffsets: IndexSet, toOffset: Int) {
        let elements = fromOffsets.map { self[$0] }
        // Remove elements at offsets manually
        for offset in fromOffsets.sorted(by: >) {
            self.remove(at: offset)
        }
        self.insert(contentsOf: elements, at: toOffset)
    }
}
