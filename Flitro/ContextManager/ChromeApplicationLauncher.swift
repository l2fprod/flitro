import Foundation
import AppKit

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
            -- Close all tabs except the last N (our tabs)
            set totalTabs to count of tabs of window id winId
            set tabsToKeep to \(urls.count)
            set tabsToClose to totalTabs - tabsToKeep
            if tabsToClose > 0 then
                repeat with i from 1 to tabsToClose
                    close tab 1 of window id winId
                end repeat
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
                -- Close all tabs in the window
                set tabCount to count of tabs of window id \(winId)
                repeat with i from tabCount to 0 by -1
                    close tab i of window id \(winId)
                end repeat
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
