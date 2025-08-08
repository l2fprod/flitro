import Foundation
import AppKit
import UniformTypeIdentifiers

struct UniversalDropHandler {
    // List of all supported drop types for maximum compatibility
    static let allDropTypes: [UTType] = [
        .fileURL,
        .url,
        .text,
        .plainText,
        .data,
        .content,
        .item,
        .json,
        .zip,
        .archive,
        .shellScript,
    ]
    
    // MARK: - Drop Processing Types
    
    private enum DropItemType {
        case fileURL
        case shellScript
        case url
        case webLocation
        case json
        case plainText
        case zipArchive
        case diskImage
    }
    
    // MARK: - Main Drop Handler
    
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
            } else if handleZipArchiveDrop(provider: provider, contextManager: contextManager, contextIndex: contextIndex) {
                handled = true
            } else if handleDiskImageDrop(provider: provider, contextManager: contextManager, contextIndex: contextIndex) {
                handled = true
            } else if handleShellScriptDrop(provider: provider, contextManager: contextManager, contextIndex: contextIndex) {
                handled = true
            } else if handleURLDrop(provider: provider, contextManager: contextManager, contextIndex: contextIndex) {
                handled = true
            } else if handleWebLocationDrop(provider: provider, contextManager: contextManager, contextIndex: contextIndex) {
                handled = true
            } else if handleJSONDrop(provider: provider, contextManager: contextManager, contextIndex: contextIndex) {
                handled = true
            } else if handlePlainTextDrop(provider: provider, contextManager: contextManager, contextIndex: contextIndex) {
                handled = true
            }
        }
        
        print("Drop handling complete. Handled: \(handled)")
        return handled
    }
    
    // MARK: - File URL Drop Handler
    
    private static func handleFileURLDrop(provider: NSItemProvider, contextManager: ContextManager, contextIndex: Int) -> Bool {
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
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
    
    // MARK: - ZIP Archive Drop Handler
    
    private static func handleZipArchiveDrop(provider: NSItemProvider, contextManager: ContextManager, contextIndex: Int) -> Bool {
        guard provider.hasItemConformingToTypeIdentifier(UTType.zip.identifier) else {
            return false
        }
        
        provider.loadItem(forTypeIdentifier: UTType.zip.identifier, options: nil) { item, error in
            if let error = error {
                print("Error loading ZIP archive: \(error)")
                return
            }
            
            guard let url = extractURL(from: item) else { return }
            
            print("Processing ZIP archive: \(url)")
            DispatchQueue.main.async {
                let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                let document = DocumentItem(
                    name: url.deletingPathExtension().lastPathComponent,
                    filePath: url.path,
                    application: "", // Let the system determine the default app
                    bookmark: bookmark
                )
                contextManager.addItem(.document(document), to: contextManager.contexts[contextIndex].id)
                print("Added ZIP archive as document: \(document.name)")
            }
        }
        return true
    }
    
    // MARK: - Disk Image Drop Handler
    
    private static func handleDiskImageDrop(provider: NSItemProvider, contextManager: ContextManager, contextIndex: Int) -> Bool {
        // Use the raw type identifier string since it's a specific macOS type
        guard provider.hasItemConformingToTypeIdentifier("com.apple.disk-image-udif") else {
            return false
        }
        
        provider.loadItem(forTypeIdentifier: "com.apple.disk-image-udif", options: nil) { item, error in
            if let error = error {
                print("Error loading disk image: \(error)")
                return
            }
            
            guard let url = extractURL(from: item) else { return }
            
            print("Processing disk image: \(url)")
            DispatchQueue.main.async {
                let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                let document = DocumentItem(
                    name: url.deletingPathExtension().lastPathComponent,
                    filePath: url.path,
                    application: "", // Let the system determine the default app
                    bookmark: bookmark
                )
                contextManager.addItem(.document(document), to: contextManager.contexts[contextIndex].id)
                print("Added disk image as document: \(document.name)")
            }
        }
        return true
    }

    // MARK: - Shell Script Drop Handler
    
    private static func handleShellScriptDrop(provider: NSItemProvider, contextManager: ContextManager, contextIndex: Int) -> Bool {
        guard provider.hasItemConformingToTypeIdentifier(UTType.shellScript.identifier) else {
            return false
        }
        
        provider.loadItem(forTypeIdentifier: UTType.shellScript.identifier, options: nil) { item, error in
            if let error = error {
                print("Error loading shell script: \(error)")
                return
            }
            
            guard let url = extractURL(from: item) else { return }
            
            DispatchQueue.main.async {
                let session = TerminalSession(
                    workingDirectory: url.deletingLastPathComponent().path,
                    command: url.path,
                    title: url.deletingPathExtension().lastPathComponent
                )
                contextManager.addItem(.terminalSession(session), to: contextManager.contexts[contextIndex].id)
                print("Added terminal session for script: \(session.title)")
            }
        }
        return true
    }
    
    // MARK: - URL Drop Handler
    
    private static func handleURLDrop(provider: NSItemProvider, contextManager: ContextManager, contextIndex: Int) -> Bool {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else {
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
    
    // MARK: - JSON Drop Handler
    
    private static func handleJSONDrop(provider: NSItemProvider, contextManager: ContextManager, contextIndex: Int) -> Bool {
        guard provider.hasItemConformingToTypeIdentifier(UTType.json.identifier) else {
            return false
        }
        
        provider.loadItem(forTypeIdentifier: UTType.json.identifier, options: nil) { item, error in
            if let error = error {
                print("Error loading JSON: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                processJSONItem(item: item, contextManager: contextManager, contextIndex: contextIndex)
            }
        }
        return true
    }
    
    // MARK: - Plain Text Drop Handler
    
    private static func handlePlainTextDrop(provider: NSItemProvider, contextManager: ContextManager, contextIndex: Int) -> Bool {
        guard provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) else {
            return false
        }
        
        let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) ? UTType.text.identifier : UTType.plainText.identifier
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
            if let text = item as? String, 
               let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), 
               url.scheme?.hasPrefix("http") == true {
                let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                DispatchQueue.main.async {
                    contextManager.addItem(.browserTab(browserTab), to: contextManager.contexts[contextIndex].id)
                    print("Added browser tab from plain text: \(browserTab.title)")
                }
            }
        }
        return true
    }
    
    // MARK: - URL Extraction Helpers
    
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
    
    // MARK: - File Processing Helpers
    
    private static func processFileURL(url: URL, contextManager: ContextManager, contextIndex: Int) {
        if url.pathExtension == "app" {
            processApplicationFile(url: url, contextManager: contextManager, contextIndex: contextIndex)
        } else if url.pathExtension == "sh" {
            processShellScriptFile(url: url, contextManager: contextManager, contextIndex: contextIndex)
        } else if url.pathExtension == "webloc" {
            processWeblocFile(url: url, contextManager: contextManager, contextIndex: contextIndex)
        } else if url.pathExtension == "zip" {
            processZipFile(url: url, contextManager: contextManager, contextIndex: contextIndex)
        } else if url.pathExtension == "dmg" {
            processDiskImageFile(url: url, contextManager: contextManager, contextIndex: contextIndex)
        } else {
            processGenericDocumentFile(url: url, contextManager: contextManager, contextIndex: contextIndex)
        }
    }
    
    private static func processZipFile(url: URL, contextManager: ContextManager, contextIndex: Int) {
        let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        let document = DocumentItem(
            name: url.deletingPathExtension().lastPathComponent,
            filePath: url.path,
            application: "", // Let the system determine the default app
            bookmark: bookmark
        )
        contextManager.addItem(.document(document), to: contextManager.contexts[contextIndex].id)
        print("Added ZIP archive as document: \(document.name)")
    }
    
    private static func processDiskImageFile(url: URL, contextManager: ContextManager, contextIndex: Int) {
        let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        let document = DocumentItem(
            name: url.deletingPathExtension().lastPathComponent,
            filePath: url.path,
            application: "", // Let the system determine the default app
            bookmark: bookmark
        )
        contextManager.addItem(.document(document), to: contextManager.contexts[contextIndex].id)
        print("Added disk image as document: \(document.name)")
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
        
        // Also add as document
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
    
    private static func processJSONItem(item: Any?, contextManager: ContextManager, contextIndex: Int) {
        // Try to parse JSON as a URL or as a document
        if let fileURL = item as? URL {
            // Add as document
            let document = DocumentItem(
                name: fileURL.deletingPathExtension().lastPathComponent,
                filePath: fileURL.path,
                application: "",
                bookmark: nil
            )
            contextManager.addItem(.document(document), to: contextManager.contexts[contextIndex].id)
            print("Added JSON file as document: \(document.name)")
        } else if let data = item as? Data {
            processJSONData(data: data, contextManager: contextManager, contextIndex: contextIndex)
        }
    }
    
    private static func processJSONData(data: Data, contextManager: ContextManager, contextIndex: Int) {
        // Try to parse as { "url": ... }
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let urlString = json["url"] as? String, let url = URL(string: urlString) {
            let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
            contextManager.addItem(.browserTab(browserTab), to: contextManager.contexts[contextIndex].id)
            print("Added browser tab from JSON: \(browserTab.title)")
        } else if let text = String(data: data, encoding: .utf8), 
                  let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), 
                  url.scheme?.hasPrefix("http") == true {
            let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
            contextManager.addItem(.browserTab(browserTab), to: contextManager.contexts[contextIndex].id)
            print("Added browser tab from JSON string: \(browserTab.title)")
        } else {
            print("JSON data did not contain a URL, added as document")
            let document = DocumentItem(
                name: "Dropped JSON",
                filePath: "",
                application: "",
                bookmark: nil
            )
            contextManager.addItem(.document(document), to: contextManager.contexts[contextIndex].id)
        }
    }
}