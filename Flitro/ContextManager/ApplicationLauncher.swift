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
    private var didLaunchApp: Bool = false
    
    init(bundleIdentifier: String, items: [ContextItem] = []) {
        self.bundleIdentifier = bundleIdentifier
        self.items = items
    }
    
    func open(singleItem: Bool = false) {
        let workspace = NSWorkspace.shared
        let wasRunning = workspace.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
        // Open the app
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        didLaunchApp = !wasRunning
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
        let workspace = NSWorkspace.shared
        if didLaunchApp {
            // Only close the app if we launched it
            let runningApps = workspace.runningApplications
            for runningApp in runningApps {
                if let bundleId = runningApp.bundleIdentifier, bundleId == bundleIdentifier {
                    let script = "tell application id \"\(bundleId)\" to quit"
                    if let appleScript = NSAppleScript(source: script) {
                        var error: NSDictionary? = nil
                        appleScript.executeAndReturnError(&error)
                    }
                }
            }
        } else {
            // App was already running: try to close only the related documents
            for item in items {
                switch item {
                case .document(let doc):
                    // Use external AppleScript if available
                    let filePath = doc.filePath
                    let scriptName = "generic-close.script"
                    print("Looking for script: \(scriptName)")
                    let scriptPath = Bundle.main.path(forResource: scriptName, ofType: nil)
                    print("Using script at path: \(String(describing: scriptPath))")
                    if let scriptPath = scriptPath, var scriptSource = try? String(contentsOfFile: scriptPath, encoding: .utf8) {
                        // Replace placeholder with actual file path
                        scriptSource = scriptSource
                            .replacingOccurrences(of: "$FILEPATH", with: filePath)
                            .replacingOccurrences(of: "$BUNDLE_IDENTIFIER", with: bundleIdentifier)
                        print("script is \(scriptSource)")
                        if let appleScript = NSAppleScript(source: scriptSource) {
                            var error: NSDictionary? = nil
                            appleScript.executeAndReturnError(&error)
                        }
                    }
                default:
                    break
                }
            }
        }
    }
}
