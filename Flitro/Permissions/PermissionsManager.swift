import Foundation
import AppKit
import ApplicationServices

/// Manager class responsible for handling accessibility and automation permissions
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var hasAccessibilityPermission = false
    @Published var hasAutomationPermission = false
    
    private init() {
        checkPermissions()
    }
    
    /// Check current permission status
    func checkPermissions() {
        hasAccessibilityPermission = checkAccessibilityPermission()
        hasAutomationPermission = checkAutomationPermission()
    }
    
    /// Check if accessibility permission is granted
    private func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Check if automation permission is granted (basic check)
    private func checkAutomationPermission() -> Bool {
        // For automation permissions, we can try to get the list of running applications
        // If this fails, it usually indicates missing permissions
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        return !runningApps.isEmpty
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
    
    /// Request automation permission by attempting to control another app
    func requestAutomationPermission() {
        // For automation permissions, we need to actually try to control another app
        // This will trigger the system permission dialog
        DispatchQueue.global(qos: .userInitiated).async {
            let workspace = NSWorkspace.shared
            
            // Try to get Finder (which should always be running)
            if let finderApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
                // Attempt to activate Finder - this may trigger automation permission dialog
                finderApp.activate(options: [])
            }
            
            DispatchQueue.main.async {
                self.checkPermissions()
            }
        }
    }
    
    /// Open System Preferences to the appropriate permission settings
    func openSystemPreferences() {
        let url: URL
        
        if #available(macOS 13.0, *) {
            // macOS Ventura and later use System Settings
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        } else {
            // macOS Monterey and earlier use System Preferences
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
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
        • Automation: Required to launch and manage applications
        
        Click "Grant Permissions" to open the permission dialogs, or "Open Settings" to manually configure permissions in System Preferences.
        """
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "Grant Permissions")
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Grant Permissions
            requestAccessibilityPermission()
            requestAutomationPermission()
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
        return hasAccessibilityPermission && hasAutomationPermission
    }
    
    /// Get a user-friendly status message
    var permissionStatusMessage: String {
        if hasAllPermissions {
            return "All permissions granted"
        } else if hasAccessibilityPermission {
            return "Automation permission needed"
        } else if hasAutomationPermission {
            return "Accessibility permission needed"
        } else {
            return "Permissions needed"
        }
    }
}
