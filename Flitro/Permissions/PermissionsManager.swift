import Foundation
import AppKit
import ApplicationServices

/// Manager class responsible for handling accessibility
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var hasAccessibilityPermission = false
    
    private init() {
        checkPermissions()
    }
    
    /// Check current permission status
    func checkPermissions() {
        hasAccessibilityPermission = checkAccessibilityPermission()
    }
    
    /// Check if accessibility permission is granted
    private func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }    
   
    /// Request accessibility permission
    func requestAccessibilityPermission() {
        // This will prompt the user to grant accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = accessEnabled
        }
    }
    
    /// Open System Preferences to the appropriate permission settings
    func openSystemPreferences() {
        let url: URL

        if #available(macOS 13.0, *) {
            // macOS Ventura and later use System Settings
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        } else {
            // macOS Monterey and earlier use System Preferences
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        }

        NSWorkspace.shared.open(url)
    }
    
    /// Show permission request dialog
    func showPermissionDialog() {
        let alert = NSAlert()
        alert.messageText = "Permissions Required"
        alert.informativeText = """
        Flitro needs accessibility and automation permissions to manage your contexts effectively.

        • Accessibility: Required to control applications and windows
        • Automation: Required to control applications like Mail, Terminal, etc.

        Click "Test Permissions" to check current status, or "Open Settings" to manually configure permissions in System Settings.
        """
        alert.alertStyle = .informational

        alert.addButton(withTitle: "Test Permissions")
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Test Permissions
            if !hasAccessibilityPermission {
                requestAccessibilityPermission()
            }
        case .alertSecondButtonReturn:
            // Open Settings
            openSystemPreferences()
        default:
            // Cancel - do nothing
            break
        }
    }
    
    /// Check if all required permissions are granted
    var hasAllPermissions: Bool {
        return hasAccessibilityPermission
    }
    
    /// Get a user-friendly status message
    var permissionStatusMessage: String {
        if hasAllPermissions {
            return "All permissions granted"
        } else if hasAccessibilityPermission {
            return "Accessibility permission needed"
        } else {
            return "Permissions needed"
        }
    }
}
