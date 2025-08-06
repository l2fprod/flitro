import Foundation
import AppKit

protocol ContextManagerListener: AnyObject {
    func contextDidOpen(contextID: UUID)
    func contextDidClose(contextID: UUID)
    func contextDidCreate(contextID: UUID)
    func contextsLoaded(_ contexts: [Context]) // Use [Any] to avoid type errors here
    func contextsSaved(_ contexts: [Context]) // Use [Any] to avoid type errors here
}
