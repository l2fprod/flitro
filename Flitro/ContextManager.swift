import Foundation
import AppKit
import ApplicationServices

// MARK: - Data Models

struct Context: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var applications: [AppItem]
    var documents: [DocumentItem]
    var browserTabs: [BrowserTab]
    var terminalSessions: [TerminalSession]
    var iconName: String? = nil
    var iconBackgroundColor: String? = nil // Optional hex color string
    var iconForegroundColor: String? = nil // Optional hex color string
    var isActive: Bool = false
    var createdAt: Date = Date()
    var lastUsed: Date = Date()
    
    static func == (lhs: Context, rhs: Context) -> Bool {
        lhs.id == rhs.id
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
    
    // Mapping from context UUID to Chrome window ID
    private var chromeWindowIDs: [UUID: Int] = [:]
    
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
            applications: applications,
            documents: documents,
            browserTabs: browserTabs,
            terminalSessions: terminalSessions,
            iconName: iconName,
            iconBackgroundColor: iconBackgroundColor,
            iconForegroundColor: iconForegroundColor
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
            applications: [],
            documents: [],
            browserTabs: [],
            terminalSessions: [],
            iconName: nil,
            iconBackgroundColor: nil,
            iconForegroundColor: nil
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
                context.applications.append(appItem)
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
        
        for contextApp in context.applications {
            for runningApp in runningApps {
                if let bundleId = runningApp.bundleIdentifier,
                   bundleId == contextApp.bundleIdentifier {
                    if !isSystemApp(bundleId) {
                        let script = "tell application id \"\(bundleId)\" to quit"
                        if let appleScript = NSAppleScript(source: script) {
                            var error: NSDictionary? = nil
                            appleScript.executeAndReturnError(&error)
                        }
                    }
                }
            }
        }

        // Close any Chrome window opened for this context (if tracked)
        closeChromeWindowForContext(context.id)
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
        for app in context.applications {
            openApp(app)
        }
    }
    
    private func launchContextDocuments(_ context: Context) {
        for doc in context.documents {
            openDocument(doc)
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
        // Determine if Chrome is the default browser
        let isChromeDefault = getDefaultBrowser() == "chrome"
        // Group tabs by browser, including 'default' tabs in Chrome if Chrome is default
        let chromeTabs: [BrowserTab]
        let otherTabs: [BrowserTab]
        if isChromeDefault {
            chromeTabs = context.browserTabs.filter { tab in
                let b = tab.browser.lowercased()
                return b == "chrome" || b == "default"
            }
            otherTabs = context.browserTabs.filter { tab in
                let b = tab.browser.lowercased()
                return b != "chrome" && b != "default"
            }
        } else {
            chromeTabs = context.browserTabs.filter { $0.browser.lowercased() == "chrome" }
            otherTabs = context.browserTabs.filter { $0.browser.lowercased() != "chrome" }
        }
        // Open Chrome tabs using Apple Events
        if !chromeTabs.isEmpty {
            print("Launching Chrome tabs: \(chromeTabs)")
            _ = launchChromeTabsWithAppleEvents(chromeTabs, for: context.id)
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
    
    private func launchSafariTabs(_ tabs: [BrowserTab], for contextId: UUID) -> Bool {
        guard !tabs.isEmpty else { return false }
        let workspace = NSWorkspace.shared
        guard let safariURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.Safari") else {
            return false
        }
        let config = NSWorkspace.OpenConfiguration()
        for tab in tabs {
            if let url = URL(string: tab.url) {
                workspace.open([url], withApplicationAt: safariURL, configuration: config) { app, error in
                    if let error = error {
                        print("Failed to open URL in Safari: \(error)")
                    }
                }
            }
        }
        return true
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
                chromeWindowIDs[contextId] = Int(winId)
                return true
            } else if let error = error {
                print("AppleScript error: \(error)")
            }
        }
        return false
    }

    /// Close the Chrome window associated with a context (by window ID)
    func closeChromeWindowForContext(_ contextId: UUID) {
        guard let winId = chromeWindowIDs[contextId] else { return }
        let script = """
        tell application \"Google Chrome\"
            if (exists window id \(winId)) then
                close window id \(winId)
            end if
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary? = nil
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("Failed to close Chrome window: \(error)")
            }
        }
        chromeWindowIDs.removeValue(forKey: contextId)
    }
    
    private func launchContextTerminals(_ context: Context) {
        for session in context.terminalSessions {
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
            contexts = try JSONDecoder().decode([Context].self, from: data)
            activeContext = contexts.first { $0.isActive }
        } catch {
            print("Failed to load contexts: \(error)")
            initializeSampleData()
        }
    }
    
    private func initializeSampleData() {
        let sampleContexts = [
            Context(
                name: "Project A",
                applications: [
                    AppItem(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
                    AppItem(name: "Figma", bundleIdentifier: "com.figma.Desktop"),
                    AppItem(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap")
                ],
                documents: [],
                browserTabs: [
                    BrowserTab(title: "Swift Documentation", url: "https://docs.swift.org", browser: "Safari"),
                    BrowserTab(title: "GitHub - Project A", url: "https://github.com/user/project-a", browser: "Safari")
                ],
                terminalSessions: [
                    TerminalSession(workingDirectory: "/Users/user/Projects/ProjectA", command: "npm run dev", title: "Development Server")
                ],
                iconName: "code"
            ),
            Context(
                name: "Team Management",
                applications: [
                    AppItem(name: "Slack", bundleIdentifier: "com.apple.tinyspeck.slackmacgap"),
                    AppItem(name: "Notion", bundleIdentifier: "notion.id"),
                    AppItem(name: "Calendar", bundleIdentifier: "com.apple.iCal")
                ],
                documents: [],
                browserTabs: [
                    BrowserTab(title: "Team Dashboard", url: "https://notion.so/team-dashboard", browser: "Safari"),
                    BrowserTab(title: "HR Portal", url: "https://company.com/hr", browser: "Safari")
                ],
                terminalSessions: [],
                iconName: "users"
            )
        ]
        
        contexts = sampleContexts
        saveContexts()
    }
} 