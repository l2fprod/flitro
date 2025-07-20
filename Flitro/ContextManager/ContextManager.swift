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
    var isActive: Bool = false
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
        hasher.combine(isActive)
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

// Migration helper for old contexts.json
extension Context {
    // Accepts a dictionary from JSONSerialization
    static func migrate(from legacy: [String: Any]) -> Context? {
        guard let name = legacy["name"] as? String else { return nil }
        let id = (legacy["id"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()
        let iconName = legacy["iconName"] as? String
        let iconBackgroundColor = legacy["iconBackgroundColor"] as? String
        let iconForegroundColor = legacy["iconForegroundColor"] as? String
        let isActive = legacy["isActive"] as? Bool ?? false
        let createdAt = (legacy["createdAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        let lastUsed = (legacy["lastUsed"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        var items: [ContextItem] = []
        if let apps = legacy["applications"] as? [[String: Any]] {
            for appDict in apps {
                if let data = try? JSONSerialization.data(withJSONObject: appDict),
                   let app = try? JSONDecoder().decode(AppItem.self, from: data) {
                    items.append(.application(app))
                }
            }
        }
        if let docs = legacy["documents"] as? [[String: Any]] {
            for docDict in docs {
                if let data = try? JSONSerialization.data(withJSONObject: docDict),
                   let doc = try? JSONDecoder().decode(DocumentItem.self, from: data) {
                    items.append(.document(doc))
                }
            }
        }
        if let tabs = legacy["browserTabs"] as? [[String: Any]] {
            for tabDict in tabs {
                if let data = try? JSONSerialization.data(withJSONObject: tabDict),
                   let tab = try? JSONDecoder().decode(BrowserTab.self, from: data) {
                    items.append(.browserTab(tab))
                }
            }
        }
        if let terms = legacy["terminalSessions"] as? [[String: Any]] {
            for termDict in terms {
                if let data = try? JSONSerialization.data(withJSONObject: termDict),
                   let term = try? JSONDecoder().decode(TerminalSession.self, from: data) {
                    items.append(.terminalSession(term))
                }
            }
        }
        return Context(id: id, name: name, items: items, iconName: iconName, iconBackgroundColor: iconBackgroundColor, iconForegroundColor: iconForegroundColor, isActive: isActive, createdAt: createdAt, lastUsed: lastUsed)
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

enum SwitchingMode: String, CaseIterable {
    case replaceAll = "Replace All"
    case additive = "Additive"
    
    var description: String {
        switch self {
        case .replaceAll:
            return "Close current context apps and open new ones"
        case .additive:
            return "Keep current apps and add new context apps"
        }
    }
}

// MARK: - Abstractions for Generic Item Handling

// MARK: - Context Manager

class ContextManager: ObservableObject {
    static let shared = ContextManager()
    @Published var contexts: [Context] = []
    @Published var activeContext: Context?
    
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
  
    func deleteContext(_ context: Context) {
        contexts.removeAll { $0.id == context.id }
        if activeContext?.id == context.id {
            activeContext = nil
        }
        // Remove all launchers for the context
        contextLaunchers.removeValue(forKey: context.id)
        saveContexts()
    }
    
    // MARK: - Context Switching
    
    func switchToContext(_ context: Context, switchingMode: SwitchingMode) {
        if switchingMode == .replaceAll {
            if let currentContext = activeContext {
                closeContext(currentContext)
            }
            activeContext = context
        }
        openContextItems(context)
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
    private func openContextItems(_ context: Context) {
        var itemsByBundle: [String: [ContextItem]] = [:]
        for item in context.items {
            if let bundleId = bundleId(for: item) {
                itemsByBundle[bundleId, default: []].append(item)
            }
        }
        var launchers: [ContextApplicationLauncher] = []
        for (bundleId, items) in itemsByBundle {
            let launcher = launcher(for: bundleId, items: items)
            launcher.open()
            launchers.append(launcher)
        }
        // Store launchers for this context
        contextLaunchers[context.id] = launchers
        // Open terminal sessions directly (not via launcher abstraction)
        for item in context.items {
            if case .terminalSession(let session) = item {
                let commandToRun: String
                if let command = session.command, !command.isEmpty {
                    commandToRun = command
                } else {
                    continue // Skip if no command
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
    
    // MARK: - Context Reordering
    /// Reorder contexts and persist the new order
    func reorderContexts(fromOffsets: IndexSet, toOffset: Int) {
        contexts.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveContexts()
    }
    
    // MARK: - Application Management
    
    func closeContext(_ context: Context) {
        // Use launchers to close apps/items
        if let launchers = contextLaunchers[context.id] {
            for launcher in launchers {
                launcher.close()
            }
            contextLaunchers.removeValue(forKey: context.id)
        }
        // No need to call closeBrowserWindowsForContext or per-item close logic anymore
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
            do {
                // Try decoding as new format
                let decoded = try JSONDecoder().decode([Context].self, from: data)
                self.contexts = decoded
            } catch {
                // Try to migrate from old format
                if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    let migrated = jsonArray.compactMap { Context.migrate(from: $0) }
                    self.contexts = migrated
                    // Save back in new format
                    saveContexts()
                } else {
                    print("Failed to decode or migrate contexts.json: \(error)")
                }
            }
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
