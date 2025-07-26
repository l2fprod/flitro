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
