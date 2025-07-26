import Foundation
import AppKit

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