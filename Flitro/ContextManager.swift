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
                closeContextApplications(currentContext)
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
    
    func closeContextApplications(_ context: Context) {
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
    
    private func launchContextBrowserTabs(_ context: Context) {
        for tab in context.browserTabs {
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
            let data = try JSONEncoder().encode(contexts)
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