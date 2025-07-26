import Foundation
import AppKit

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