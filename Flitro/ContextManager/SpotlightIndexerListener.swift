import Foundation
import AppKit
import CoreSpotlight
import UniformTypeIdentifiers
import SwiftUI
import PhosphorSwift

class SpotlightIndexerListener: ContextManagerListener {

    private let contextManager: ContextManager

    init(contextManager: ContextManager) {
        self.contextManager = contextManager
    }

    private func updateActivities() {
        let contexts = contextManager.contexts

        print("[SpotlightIndexerListener] Indexing \(contexts.count) contexts with Core Spotlight")
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.l2fprod.flitro.context"]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[SpotlightIndexerListener] Error deleting domain items: \(error)")
                } else {
                    print("[SpotlightIndexerListener] Deleted all items in domain before re-indexing")
                }
                // Now index current items
                var searchableItems: [CSSearchableItem] = []
                for context in contexts {
                    let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.item.identifier)
                    attributeSet.title = context.name
                    attributeSet.contentDescription = "Select to toggle the context \(context.name)."
                    attributeSet.keywords = [context.name, context.name.lowercased(), "context", "project", "workspace", "flitro", "Flitro",]
                    attributeSet.identifier = context.id.uuidString
                    // Use shared SidebarContextIconView for icon rendering
                    let iconView = ContextIconView(context: context, size: 32, animate: false, rotation: 0)
                    let hostingView = NSHostingView(rootView: iconView)
                    hostingView.frame = NSRect(x: 0, y: 0, width: 32, height: 32)
                    let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
                    hostingView.cacheDisplay(in: hostingView.bounds, to: rep!)
                    let nsImage = NSImage(size: NSSize(width: 32, height: 32))
                    nsImage.addRepresentation(rep!)
                    if let tiffData = nsImage.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        attributeSet.thumbnailData = pngData
                    }
                    let item = CSSearchableItem(uniqueIdentifier: context.id.uuidString, domainIdentifier: "com.l2fprod.flitro.context", attributeSet: attributeSet)
                    searchableItems.append(item)
                    print("[SpotlightIndexerListener] Indexed context: \(context.name)")
                }
                CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
                    if let error = error {
                        print("[SpotlightIndexerListener] Error indexing contexts: \(error)")
                    } else {
                        print("[SpotlightIndexerListener] Successfully indexed contexts for Spotlight")
                    }
                }
            }
        }
    }

    func contextDidCreate(contextID: UUID) {}

    func contextDidOpen(contextID: UUID) {
      updateActivities()

    }
    func contextDidClose(contextID: UUID) {
        updateActivities()
    }

    func contextsSaved(_ contexts: [Context]) {
        updateActivities()
    }

    func contextsLoaded(_ contexts: [Context]) {
        updateActivities()
    }
}
