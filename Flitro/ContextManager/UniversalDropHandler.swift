import Foundation
import AppKit
import UniformTypeIdentifiers

struct UniversalDropHandler {
    // List of all supported drop types for maximum compatibility
    static let allDropTypes: [UTType] = [
        .fileURL, // most dropped files
        .url, // web links
        .init(exportedAs: "com.apple.web-internet-location"), // Safari .webloc files
    ]
    
    // MARK: - Drop Handler
    static func handleUniversalDrop(providers: [NSItemProvider], contextManager: ContextManager, selectedContextID: UUID?) -> Bool {
        guard let contextIndex = contextManager.contexts.firstIndex(where: { $0.id == selectedContextID }) else {
            print("No selected context found for drop")
            return false
        }
        guard !providers.isEmpty else {
            print("No providers in drop")
            return false
        }
        
        var handled = false
        for provider in providers {
            print("Processing provider with types: \(provider.registeredTypeIdentifiers)")
            if handleFileURLDrop(provider: provider, contextManager: contextManager, contextIndex: contextIndex) {
                handled = true
            } else if handleURLDrop(provider: provider, contextManager: contextManager, contextIndex: contextIndex) {
                handled = true
            } else if handleWebLocationDrop(provider: provider, contextManager: contextManager, contextIndex: contextIndex) {
                handled = true
            }
            if handled {
                break
            }
        }
        
        print("Drop handling complete. Handled: \(handled)")
        return handled
    }
    
    // MARK: - File URL Drop Handler
    private static func handleFileURLDrop(provider: NSItemProvider, contextManager: ContextManager, contextIndex: Int) -> Bool {
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            print("Provider does not conform to file URL type")
            return false
        }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let error = error {
                print("Error loading file URL: \(error)")
                return
            }
            
            guard let url = extractURL(from: item) else { return }
            
            print("Processing URL: \(url)")
            DispatchQueue.main.async {
                processFileURL(url: url, contextManager: contextManager, contextIndex: contextIndex)
            }
        }
        return true
    }

    private static func extractURL(from item: Any?) -> URL? {
        if let urlObject = item as? URL {
            return urlObject
        } else if let data = item as? Data {
            let url = URL(dataRepresentation: data, relativeTo: nil)
            print("Converted data to URL: \(String(describing: url))")
            return url
        } else if let str = item as? String {
            return URL(string: str)
        }
        return nil
    }

    private static func processFileURL(url: URL, contextManager: ContextManager, contextIndex: Int) {
        if url.pathExtension == "app" {
            processApplicationFile(url: url, contextManager: contextManager, contextIndex: contextIndex)
        } else if url.pathExtension == "sh" {
            processShellScriptFile(url: url, contextManager: contextManager, contextIndex: contextIndex)
        } else if url.pathExtension == "webloc" {
            processWeblocFile(url: url, contextManager: contextManager, contextIndex: contextIndex)
        } else {
            processGenericDocumentFile(url: url, contextManager: contextManager, contextIndex: contextIndex)
        }
    }

    private static func processApplicationFile(url: URL, contextManager: ContextManager, contextIndex: Int) {
        if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
            let appItem = AppItem(name: url.deletingPathExtension().lastPathComponent, bundleIdentifier: bundleId, windowTitle: nil)
            contextManager.addItem(.application(appItem), to: contextManager.contexts[contextIndex].id)
            print("Added application: \(appItem.name)")
        }
    }

    private static func processShellScriptFile(url: URL, contextManager: ContextManager, contextIndex: Int) {
        let session = TerminalSession(
            workingDirectory: url.deletingLastPathComponent().path,
            command: url.path,
            title: url.deletingPathExtension().lastPathComponent
        )
        contextManager.addItem(.terminalSession(session), to: contextManager.contexts[contextIndex].id)
        print("Added terminal session for script: \(session.title)")
    }

    private static func processWeblocFile(url: URL, contextManager: ContextManager, contextIndex: Int) {
        // Read the .webloc file and extract the URL
        if let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let urlString = dict["URL"] as? String, let realURL = URL(string: urlString) {
            let browserTab = BrowserTab(title: realURL.absoluteString, url: realURL.absoluteString, browser: "default")
            contextManager.addItem(.browserTab(browserTab), to: contextManager.contexts[contextIndex].id)
            print("Added browser tab from .webloc: \(browserTab.title)")
        } else {
            print("Failed to extract URL from .webloc file: \(url)")
        }
    }

    private static func processGenericDocumentFile(url: URL, contextManager: ContextManager, contextIndex: Int) {
        let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        let document = DocumentItem(
            name: url.deletingPathExtension().lastPathComponent,
            filePath: url.path,
            application: "",
            bookmark: bookmark
        )
        contextManager.addItem(.document(document), to: contextManager.contexts[contextIndex].id)
        print("Added document: \(document.name)")
    }

    // MARK: - URL Drop Handler
    private static func handleURLDrop(provider: NSItemProvider, contextManager: ContextManager, contextIndex: Int) -> Bool {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else {
            print("Provider does not conform to URL type")
            return false
        }
        
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
            if let error = error {
                print("Error loading URL: \(error)")
                return
            }
            
            if let url = extractURL(from: item) {
                let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                DispatchQueue.main.async {
                    contextManager.addItem(.browserTab(browserTab), to: contextManager.contexts[contextIndex].id)
                    print("Added browser tab: \(browserTab.title)")
                }
            }
        }
        return true
    }
    
    // MARK: - Web Location Drop Handler
    private static func handleWebLocationDrop(provider: NSItemProvider, contextManager: ContextManager, contextIndex: Int) -> Bool {
        guard provider.hasItemConformingToTypeIdentifier("com.apple.web-internet-location") else {
            print("Provider does not conform to web-internet-location type")
            return false
        }
        
        provider.loadItem(forTypeIdentifier: "com.apple.web-internet-location", options: nil) { item, error in
            if let error = error {
                print("Error loading web-internet-location: \(error)")
                return
            }
            
            let url = extractWebLocationURL(from: item)
            if let url = url {
                let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                DispatchQueue.main.async {
                    contextManager.addItem(.browserTab(browserTab), to: contextManager.contexts[contextIndex].id)
                    print("Added browser tab from web-internet-location: \(browserTab.title)")
                }
            } else {
                print("Could not extract URL from com.apple.web-internet-location drop")
            }
        }
        return true
    }

    private static func extractWebLocationURL(from item: Any?) -> URL? {
        // If item is a file URL, read the .webloc file and extract the URL
        if let fileURL = item as? URL {
            if let data = try? Data(contentsOf: fileURL),
               let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let urlString = dict["URL"] as? String, let parsedURL = URL(string: urlString) {
                return parsedURL
            } else {
                print("Could not extract URL from .webloc file at: \(fileURL)")
            }
        } else if let data = item as? Data {
            // Try to parse Data as property list
            if let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let urlString = dict["URL"] as? String, let parsedURL = URL(string: urlString) {
                return parsedURL
            } else if let urlString = String(data: data, encoding: .utf8), let parsedURL = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsedURL
            }
        }
        return nil
    }
}