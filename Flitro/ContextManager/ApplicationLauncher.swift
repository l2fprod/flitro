import Foundation
import AppKit

// Protocol for application launchers
protocol ContextApplicationLauncher: AnyObject {
    var bundleIdentifier: String { get }
    var items: [ContextItem] { get set }
    /// Opens the items. If singleItem is true, should open in the active window/tab if possible.
    func open(singleItem: Bool)
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
    
    func open(singleItem: Bool = false) {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            workspace.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            // Open items (e.g., documents) with the specified app
            for item in items {
                switch item {
                case .document(let doc):
                    let fileURL = URL(fileURLWithPath: doc.filePath)
                    workspace.open([fileURL], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                default:
                    break
                }
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
