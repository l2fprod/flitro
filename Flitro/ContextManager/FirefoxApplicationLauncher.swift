import Foundation
import AppKit

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