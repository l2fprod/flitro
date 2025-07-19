import Foundation
import AppKit

// Protocol for application launchers
protocol ContextApplicationLauncher: AnyObject {
    var bundleIdentifier: String { get }
    var items: [ContextItem] { get set }
    func open()
    func close()
}

// Default launcher for generic apps and documents
class DefaultApplicationLauncher: ContextApplicationLauncher {
    let bundleIdentifier: String
    var items: [ContextItem]
    
    init(bundleIdentifier: String, items: [ContextItem] = []) {
        self.bundleIdentifier = bundleIdentifier
        self.items = items
    }
    
    func open() {
        // Open the app
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        // Open items (e.g., documents)
        for item in items {
            switch item {
            case .document(let doc):
                let fileURL = URL(fileURLWithPath: doc.filePath)
                workspace.open(fileURL)
            default:
                break
            }
        }
    }
    
    func close() {
        // Close the app (generic)
        let runningApps = NSWorkspace.shared.runningApplications
        for runningApp in runningApps {
            if let bundleId = runningApp.bundleIdentifier, bundleId == bundleIdentifier {
                let script = "tell application id \"\(bundleId)\" to quit"
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary? = nil
                    appleScript.executeAndReturnError(&error)
                }
            }
        }
    }
}

// Chrome-specific launcher for opening/closing tabs in one window
class ChromeApplicationLauncher: ContextApplicationLauncher {
    let bundleIdentifier: String = "com.google.Chrome"
    var items: [ContextItem]
    private var windowId: Int? = nil
    
    init(items: [ContextItem] = []) {
        self.items = items
    }
    
    func open() {
        // Collect all browser tabs
        let tabs = items.compactMap { item -> BrowserTab? in
            if case .browserTab(let tab) = item { return tab } else { return nil }
        }
        guard !tabs.isEmpty else { return }
        let urls = tabs.map { $0.url }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !urls.isEmpty else { return }
        let urlList = urls.map { "\"\($0)\"" }.joined(separator: ", ")
        let script = """
        tell application \"Google Chrome\"
            activate
            make new window
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
                self.windowId = Int(winId)
            }
        }
    }
    
    func close() {
        guard let winId = windowId else { return }
        let script = """
        tell application \"Google Chrome\"
            if (exists window id \(winId)) then
                try
                    close window id \(winId)
                end try
            end if
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary? = nil
            appleScript.executeAndReturnError(&error)
        }
    }
}

// Safari-specific launcher for opening/closing tabs in one window
class SafariApplicationLauncher: ContextApplicationLauncher {
    let bundleIdentifier: String = "com.apple.Safari"
    var items: [ContextItem]
    private var windowId: Int? = nil
    
    init(items: [ContextItem] = []) { self.items = items }
    
    func open() {
        let tabs = items.compactMap { item -> BrowserTab? in
            if case .browserTab(let tab) = item { return tab } else { return nil }
        }
        guard !tabs.isEmpty else { return }
        let urls = tabs.map { $0.url }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !urls.isEmpty else { return }
        let urlList = urls.map { "\"\($0)\"" }.joined(separator: ", ")
        let safariIsRunning = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).count > 0
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
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary? = nil
            let result = appleScript.executeAndReturnError(&error)
            let winId = result.int32Value
            if winId != 0 {
                self.windowId = Int(winId)
            }
        }
    }
    
    func close() {
        guard let winId = windowId else { return }
        let script = """
        tell application \"Safari\"
            if (exists window id \(winId)) then
                try
                    close window id \(winId)
                end try
            end if
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary? = nil
            appleScript.executeAndReturnError(&error)
        }
    }
}

// Firefox-specific launcher for opening/closing tabs in one window
class FirefoxApplicationLauncher: ContextApplicationLauncher {
    let bundleIdentifier: String = "org.mozilla.firefox"
    var items: [ContextItem]
    private var opened: Bool = false // Can't track window id in Firefox
    
    init(items: [ContextItem] = []) { self.items = items }
    
    func open() {
        let tabs = items.compactMap { item -> BrowserTab? in
            if case .browserTab(let tab) = item { return tab } else { return nil }
        }
        guard !tabs.isEmpty else { return }
        let urls = tabs.map { $0.url }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !urls.isEmpty else { return }
        let urlList = urls.map { "\"\($0)\"" }.joined(separator: ", ")
        let script = """
        tell application \"Firefox\"
            activate
            set win to (make new window)
            set tabUrls to { \(urlList) }
            repeat with theUrl in tabUrls
                open location theUrl
            end repeat
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary? = nil
            appleScript.executeAndReturnError(&error)
            self.opened = true
        }
    }
    
    func close() {
        // No reliable way to close only the window we opened in Firefox via AppleScript
        // Optionally, could try to close the frontmost window, but this is risky
    }
}

// Preview-specific launcher for opening/closing documents
class PreviewApplicationLauncher: ContextApplicationLauncher {
    let bundleIdentifier: String = "com.apple.Preview"
    var items: [ContextItem]
    private var openedFilePaths: [String] = []
    
    init(items: [ContextItem] = []) {
        self.items = items
    }
    
    func open() {
        let workspace = NSWorkspace.shared
        for item in items {
            if case .document(let doc) = item {
                let fileURL = URL(fileURLWithPath: doc.filePath)
                workspace.open(fileURL)
                openedFilePaths.append(doc.filePath)
            }
        }
    }
    
    func close() {
        for fileToClose in openedFilePaths {
            let script = """
            tell application \"Preview\"
                repeat with d in documents
                    try
                        if path of d is equal to \"\(fileToClose)\" then
                            close d
                        end if
                    end try
                end repeat
            end tell
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary? = nil
                appleScript.executeAndReturnError(&error)
            }
        }
    }
} 