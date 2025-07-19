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
    var items: [ContextItem]
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
    case hybrid = "Smart Replace"
    
    var description: String {
        switch self {
        case .replaceAll:
            return "Close current context apps and open new ones"
        case .additive:
            return "Keep current apps and add new context apps"
        case .hybrid:
            return "Close non-essential apps, keep productivity apps"
        }
    }
}

// MARK: - Context Manager

class ContextManager: ObservableObject {
    static let shared = ContextManager()
    @Published var contexts: [Context] = []
    @Published var activeContext: Context?
    
    // Mapping from context UUID to Chrome window IDs
    private var chromeWindowIDs: [UUID: [Int]] = [:]
    // Mapping from context UUID to Safari window IDs
    private var safariWindowIDs: [UUID: [Int]] = [:]
    
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
    
    init() {
        loadContexts()
    }
    
    // MARK: - Context Management
    
    func createContext(name: String, applications: [AppItem] = [], documents: [DocumentItem] = [], browserTabs: [BrowserTab] = [], terminalSessions: [TerminalSession] = [], iconName: String? = nil, iconBackgroundColor: String? = nil, iconForegroundColor: String? = nil) {
        let context = Context(
            name: name,
            items: applications.map { .application($0) } + documents.map { .document($0) } + browserTabs.map { .browserTab($0) } + terminalSessions.map { .terminalSession($0) }
        )
        contexts.append(context)
        saveContexts()
    }
    
    func addContext(_ context: Context) {
        contexts.append(context)
        saveContexts()
    }
    
    func updateContext(_ context: Context) {
        if let index = contexts.firstIndex(where: { $0.id == context.id }) {
            contexts[index] = context
            saveContexts()
        }
    }
    
    func deleteContext(_ context: Context) {
        contexts.removeAll { $0.id == context.id }
        if activeContext?.id == context.id {
            activeContext = nil
        }
        saveContexts()
    }
    
    func getContext(by id: UUID) -> Context? {
        return contexts.first { $0.id == id }
    }
    
    func getContextIndex(by id: UUID) -> Int? {
        return contexts.firstIndex { $0.id == id }
    }
    
    func captureCurrentWorkspace() -> Context {
        var context = Context(
            name: "New Context",
            items: []
        )
        
        // Capture running applications
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        for app in runningApps {
            if let bundleId = app.bundleIdentifier,
               let appName = app.localizedName,
               !app.isHidden && app.activationPolicy == .regular {
                
                let appItem = AppItem(
                    name: appName,
                    bundleIdentifier: bundleId,
                    windowTitle: nil
                )
                context.items.append(.application(appItem))
            }
        }
        
        return context
    }
    
    // MARK: - Context Switching
    
    func switchToContext(_ context: Context, switchingMode: SwitchingMode) {
        // Handle different switching modes
        switch switchingMode {
        case .replaceAll:
            // Close applications and browser windows from current context
            if let currentContext = activeContext {
                closeContext(currentContext)
            }
            
            // Set new active context
            activeContext = context
            
            // Launch applications for the new context
            launchContextApplications(context)
            launchContextDocuments(context)
            launchContextBrowserTabs(context)
            launchContextTerminals(context)
            saveContexts()
            
        case .additive:
            // Launch applications for the new context without closing current ones
            launchContextApplications(context)
            launchContextDocuments(context)
            launchContextBrowserTabs(context)
            launchContextTerminals(context)
            saveContexts()
            
        case .hybrid:
            // Just launch the new context's applications
            launchContextApplications(context)
            launchContextDocuments(context)
            launchContextBrowserTabs(context)
            launchContextTerminals(context)
            saveContexts()
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
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        for item in context.items {
            switch item {
            case .application(let app):
                for runningApp in runningApps {
                    if let bundleId = runningApp.bundleIdentifier,
                       bundleId == app.bundleIdentifier {
                        if !isSystemApp(bundleId) {
                            let script = "tell application id \"\(bundleId)\" to quit"
                            if let appleScript = NSAppleScript(source: script) {
                                var error: NSDictionary? = nil
                                appleScript.executeAndReturnError(&error)
                            }
                        }
                    }
                }
            case .browserTab:
                // No-op here; handled by closeChromeWindowForContext/closeSafariWindowsForContext below
                break
            case .document:
                // Do nothing (do not open documents on close)
                break
            case .terminalSession:
                // Do nothing (do not launch terminal sessions on close)
                break
            }
        }

        // Close any Chrome window opened for this context (if tracked)
        closeChromeWindowForContext(context.id)
        // Close any Safari windows opened for this context (if tracked)
        closeSafariWindowsForContext(context.id)
    }
    
    private func isSystemApp(_ bundleIdentifier: String) -> Bool {
        let systemApps = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.systemuiserver",
            "com.apple.controlcenter",
            "com.apple.notificationcenterui",
            "com.apple.loginwindow",
            "com.apple.WindowManager",
            "com.apple.ActivityMonitor"
        ]
        
        return systemApps.contains(bundleIdentifier) || bundleIdentifier.hasPrefix("com.apple.") && bundleIdentifier.contains("system")
    }
    
    private func launchContextApplications(_ context: Context) {
        for item in context.items {
            switch item {
            case .application(let app):
                openApp(app)
            default:
                break // No other application-specific launch logic here
            }
        }
    }
    
    private func launchContextDocuments(_ context: Context) {
        for item in context.items {
            switch item {
            case .document(let doc):
                openDocument(doc)
            default:
                break // No other document-specific launch logic here
            }
        }
    }

    /// Returns the default browser used on this Mac as a string: "google", "safari", "firefox", or "other"
    func getDefaultBrowser() -> String {
        let workspace = NSWorkspace.shared
        guard let httpURL = URL(string: "http://example.com") else {
            return "other"
        }
        if let appURL = workspace.urlForApplication(toOpen: httpURL) {
            let bundleID = Bundle(url: appURL)?.bundleIdentifier ?? ""
            switch bundleID {
            case "com.google.Chrome":
                return "chrome"
            case "com.apple.Safari":
                return "safari"
            case "org.mozilla.firefox":
                return "firefox"
            default:
                return "other"
            }
        }
        return "other"
    }
    
    private func launchContextBrowserTabs(_ context: Context) {
        // Group tabs by explicit browser type
        var chromeTabs = context.items.compactMap { item -> BrowserTab? in
            if case .browserTab(let tab) = item, tab.browser.lowercased() == "chrome" {
                return tab
            }
            return nil
        }
        var safariTabs = context.items.compactMap { item -> BrowserTab? in
            if case .browserTab(let tab) = item, tab.browser.lowercased() == "safari" {
                return tab
            }
            return nil
        }
        var firefoxTabs = context.items.compactMap { item -> BrowserTab? in
            if case .browserTab(let tab) = item, tab.browser.lowercased() == "firefox" {
                return tab
            }
            return nil
        }
        var otherTabs = context.items.compactMap { item -> BrowserTab? in
            if case .browserTab(let tab) = item, !["chrome", "safari", "firefox", "default"].contains(tab.browser.lowercased()) {
                return tab
            }
            return nil
        }
        let defaultTabs = context.items.compactMap { item -> BrowserTab? in
            if case .browserTab(let tab) = item, tab.browser.lowercased() == "default" {
                return tab
            }
            return nil
        }

        // Assign default tabs to the detected default browser
        let defaultBrowser = getDefaultBrowser()
        switch defaultBrowser {
        case "chrome":
            chromeTabs += defaultTabs
        case "safari":
            safariTabs += defaultTabs
        case "firefox":
            firefoxTabs += defaultTabs
        default:
            otherTabs += defaultTabs
        }

        // Open Chrome tabs using Apple Events
        if !chromeTabs.isEmpty {
            print("Launching Chrome tabs: \(chromeTabs)")
            _ = launchChromeTabsWithAppleEvents(chromeTabs, for: context.id)
        }
        // Open Safari tabs using Apple Events
        if !safariTabs.isEmpty {
            print("Launching Safari tabs: \(safariTabs)")
            _ = launchSafariTabsWithAppleEvents(safariTabs, for: context.id)
        }
        // Open Firefox tabs
        if !firefoxTabs.isEmpty {
            print("Launching Firefox tabs: \(firefoxTabs)")
            _ = launchFirefoxTabs(firefoxTabs, for: context.id)
        }
        // Open other tabs using the existing method
        for tab in otherTabs {
            openBrowserTab(tab)
        }
    }
    
    private func launchTabsInDefaultBrowser(_ tabs: [BrowserTab], for contextId: UUID) {
        let workspace = NSWorkspace.shared
        
        for tab in tabs {
            if let url = URL(string: tab.url) {
                workspace.open(url)
            }
        }
    }
    
    /// Launch Safari tabs using Apple Events (AppleScript), creating a new window and opening all tabs
    private func launchSafariTabsWithAppleEvents(_ tabs: [BrowserTab], for contextId: UUID) -> Bool {
        guard !tabs.isEmpty else { return false }
        let safariIsRunning = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").count > 0
        let urls = tabs.map { $0.url }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !urls.isEmpty else { return false }
        let urlList = urls.map { "\"\($0)\"" }.joined(separator: ", ")
        let script: String
        if urls.count == 1 {
            if safariIsRunning {
                script = """
                tell application \"Safari\"
                    activate
                    make new document
                    set URL of current tab of front window to \(urlList)
                    set winId to id of front window
                    return winId
                end tell
                """
            } else {
                script = """
                tell application \"Safari\"
                    activate
                    delay 0.5
                    try
                        close window 1
                    end try
                    make new document
                    set URL of current tab of front window to \(urlList)
                    set winId to id of front window
                    return winId
                end tell
                """
            }
        } else {
            if safariIsRunning {
                script = """
                tell application \"Safari\"
                    activate
                    make new document
                    set tabUrls to { \(urlList) }
                    set URL of current tab of front window to (item 1 of tabUrls)
                    repeat with i from 2 to count of tabUrls
                        tell front window to set newTab to make new tab at end of tabs
                        set URL of newTab to (item i of tabUrls)
                    end repeat
                    set winId to id of front window
                    return winId
                end tell
                """
            } else {
                script = """
                tell application \"Safari\"
                    activate
                    delay 0.5
                    try
                        close window 1
                    end try
                    make new document
                    set tabUrls to { \(urlList) }
                    set URL of current tab of front window to (item 1 of tabUrls)
                    repeat with i from 2 to count of tabUrls
                        tell front window to set newTab to make new tab at end of tabs
                        set URL of newTab to (item i of tabUrls)
                    end repeat
                    set winId to id of front window
                    return winId
                end tell
                """
            }
        }
        print(script)
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary? = nil
            let result = appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error (Safari): \(error)")
                return false
            }
            let winId = result.int32Value
            if winId != 0 {
                if safariWindowIDs[contextId] != nil {
                    safariWindowIDs[contextId]?.append(Int(winId))
                } else {
                    safariWindowIDs[contextId] = [Int(winId)]
                }
                return true
            }
            return true // fallback, even if winId is 0
        }
        return false
    }
    
    private func launchChromeTabs(_ tabs: [BrowserTab], for contextId: UUID) -> Bool {
        guard !tabs.isEmpty else { return false }
        let workspace = NSWorkspace.shared
        guard let chromeURL = workspace.urlForApplication(withBundleIdentifier: "com.google.Chrome") else {
            return false
        }
        let config = NSWorkspace.OpenConfiguration()
        for tab in tabs {
            if let url = URL(string: tab.url) {
                workspace.open([url], withApplicationAt: chromeURL, configuration: config) { app, error in
                    if let error = error {
                        print("Failed to open URL in Chrome: \(error)")
                    }
                }
            }
        }
        return true
    }
    
    private func launchFirefoxTabs(_ tabs: [BrowserTab], for contextId: UUID) -> Bool {
        guard !tabs.isEmpty else { return false }
        let workspace = NSWorkspace.shared
        guard let firefoxURL = workspace.urlForApplication(withBundleIdentifier: "org.mozilla.firefox") else {
            return false
        }
        let config = NSWorkspace.OpenConfiguration()
        for tab in tabs {
            if let url = URL(string: tab.url) {
                workspace.open([url], withApplicationAt: firefoxURL, configuration: config) { app, error in
                    if let error = error {
                        print("Failed to open URL in Firefox: \(error)")
                    }
                }
            }
        }
        return true
    }
    
    /// Launch Chrome tabs using Apple Events (AppleScript), creating a new window and tracking its ID
    func launchChromeTabsWithAppleEvents(_ tabs: [BrowserTab], for contextId: UUID) -> Bool {
        guard !tabs.isEmpty else { return false }
        // Build AppleScript
        let urls = tabs.map { $0.url }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !urls.isEmpty else { return false }
        let urlList = urls.map { "\"\($0)\"" }.joined(separator: ", ")
        let script = """
        tell application \"Google Chrome\"
            activate
            if not (exists window 1) then
                make new window
            else
                make new window
            end if
            set winId to id of front window
            set tabUrls to { \(urlList) }
            repeat with theUrl in tabUrls
                tell window id winId to make new tab with properties {URL:theUrl}
            end repeat
            -- Remove the default blank tab
            if (count of tabs of window id winId) > (count of tabUrls) then
                try
                    close tab 1 of window id winId
                end try
            end if
            return winId
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary? = nil
            let result = appleScript.executeAndReturnError(&error)
            let winId = result.int32Value
            if winId != 0 {
                if chromeWindowIDs[contextId] != nil {
                    chromeWindowIDs[contextId]?.append(Int(winId))
                } else {
                    chromeWindowIDs[contextId] = [Int(winId)]
                }
                return true
            } else if let error = error {
                print("AppleScript error: \(error)")
            }
        }
        return false
    }

    /// Close all Chrome windows associated with a context (by window IDs)
    func closeChromeWindowForContext(_ contextId: UUID) {
        guard let winIds = chromeWindowIDs[contextId], !winIds.isEmpty else { return }
        let winIdList = winIds.map { String($0) }.joined(separator: ", ")
        let script = """
        tell application \"Google Chrome\"
            repeat with wid in {\(winIdList)}
                if (exists window id wid) then
                    try
                        close window id wid
                    end try
                end if
            end repeat
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary? = nil
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("Failed to close Chrome window(s): \(error)")
            }
        }
        chromeWindowIDs.removeValue(forKey: contextId)
    }
    
    /// Close the Safari windows associated with a context (by window IDs)
    private func closeSafariWindowsForContext(_ contextId: UUID) {
        guard let winIds = safariWindowIDs[contextId], !winIds.isEmpty else { return }
        let winIdList = winIds.map { String($0) }.joined(separator: ", ")
        let script = """
        tell application \"Safari\"
            repeat with wid in {\(winIdList)}
                if (exists window id wid) then
                    try
                        close window id wid
                    end try
                end if
            end repeat
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary? = nil
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("Failed to close Safari window(s): \(error)")
            }
        }
        safariWindowIDs.removeValue(forKey: contextId)
    }
    
    private func launchContextTerminals(_ context: Context) {
        for item in context.items {
            switch item {
            case .terminalSession(let session):
                let commandToRun: String
                if let command = session.command, !command.isEmpty {
                    commandToRun = command
                } else {
                    continue // Skip if no command
                }
                let workingDir = session.workingDirectory
                // AppleScript to open Terminal and run the command in the working directory
                let script = """
                tell application \"Terminal\"
                    activate
                    do script \"cd \" & quoted form of \"\(workingDir)\" & \"; \(commandToRun)\"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary? = nil
                    appleScript.executeAndReturnError(&error)
                    if let error = error {
                        print("Failed to launch terminal session: \(error)")
                    }
                }
            default:
                break // No other terminal-specific launch logic here
            }
        }
    }
    
    // MARK: - Single Item Launching
    
    func openApp(_ app: AppItem) {
        let workspace = NSWorkspace.shared
        if !app.bundleIdentifier.isEmpty {
            if let url = workspace.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
                workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }
    
    func openDocument(_ doc: DocumentItem) {
        let workspace = NSWorkspace.shared
        if let bookmark = doc.bookmark {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, 
                                options: .withSecurityScope, 
                                relativeTo: nil, 
                                bookmarkDataIsStale: &isStale) {
                let success = url.startAccessingSecurityScopedResource()
                if success {
                    workspace.open(url)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        } else {
            let fileURL = URL(fileURLWithPath: doc.filePath)
            workspace.open(fileURL)
        }
    }
    
    func openBrowserTab(_ tab: BrowserTab) {
        let workspace = NSWorkspace.shared
        let url = URL(string: tab.url)
        guard let url = url else { return }
        let browser = tab.browser.lowercased()
        switch browser {
        case "safari":
            if let safariURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                workspace.open([url], withApplicationAt: safariURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            } else {
                workspace.open(url)
            }
        case "chrome":
            if let chromeURL = workspace.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
                workspace.open([url], withApplicationAt: chromeURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            } else {
                workspace.open(url)
            }
        case "firefox":
            if let firefoxURL = workspace.urlForApplication(withBundleIdentifier: "org.mozilla.firefox") {
                workspace.open([url], withApplicationAt: firefoxURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            } else {
                workspace.open(url)
            }
        default:
            workspace.open(url)
        }
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
    
    private func initializeSampleData() {
        let sampleContexts = [
            Context(
                name: "Project A",
                items: [
                    .application(AppItem(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")),
                    .application(AppItem(name: "Figma", bundleIdentifier: "com.figma.Desktop")),
                    .application(AppItem(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"))
                ]
            ),
            Context(
                name: "Team Management",
                items: [
                    .application(AppItem(name: "Slack", bundleIdentifier: "com.apple.tinyspeck.slackmacgap")),
                    .application(AppItem(name: "Notion", bundleIdentifier: "notion.id")),
                    .application(AppItem(name: "Calendar", bundleIdentifier: "com.apple.iCal"))
                ]
            )
        ]
        
        contexts = sampleContexts
        saveContexts()
    }
} 