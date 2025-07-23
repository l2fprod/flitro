import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AppKit

struct UniversalDropHandler {
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
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) || provider.hasItemConformingToTypeIdentifier("public.file-url") {
                let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ? UTType.fileURL.identifier : "public.file-url"
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                    if let error = error {
                        print("Error loading file URL: \(error)")
                        return
                    }
                    print("Loaded item: \(String(describing: item))")
                    var url: URL?
                    if let urlObject = item as? URL {
                        url = urlObject
                    } else if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                        print("Converted data to URL: \(String(describing: url))")
                    }
                    if let url = url {
                        print("Processing URL: \(url)")
                        DispatchQueue.main.async {
                            if url.pathExtension == "app" {
                                if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                                    let appItem = AppItem(name: url.deletingPathExtension().lastPathComponent, bundleIdentifier: bundleId, windowTitle: nil)
                                    contextManager.addItem(.application(appItem), to: contextManager.contexts[contextIndex].id)
                                    print("Added application: \(appItem.name)")
                                }
                            } else if url.pathExtension == "sh" {
                                let session = TerminalSession(
                                    workingDirectory: url.deletingLastPathComponent().path,
                                    command: url.path,
                                    title: url.deletingPathExtension().lastPathComponent
                                )
                                contextManager.addItem(.terminalSession(session), to: contextManager.contexts[contextIndex].id)
                                print("Added terminal session for script: \(session.title)")
                                var bookmark: Data? = nil
                                do {
                                    bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                                } catch {
                                    bookmark = nil
                                }
                                let document = DocumentItem(
                                    name: url.deletingPathExtension().lastPathComponent,
                                    filePath: url.path,
                                    application: "",
                                    bookmark: bookmark
                                )
                                contextManager.addItem(.document(document), to: contextManager.contexts[contextIndex].id)
                                print("Added document: \(document.name)")
                            } else {
                                // Fallback: add as document for any other file type
                                var bookmark: Data? = nil
                                do {
                                    bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                                } catch {
                                    bookmark = nil
                                }
                                let document = DocumentItem(
                                    name: url.deletingPathExtension().lastPathComponent,
                                    filePath: url.path,
                                    application: "",
                                    bookmark: bookmark
                                )
                                contextManager.addItem(.document(document), to: contextManager.contexts[contextIndex].id)
                                print("Added document: \(document.name)")
                            }
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier("public.shell-script") {
                provider.loadItem(forTypeIdentifier: "public.shell-script", options: nil) { item, error in
                    if let error = error {
                        print("Error loading shell script: \(error)")
                        return
                    }
                    var url: URL?
                    if let urlObject = item as? URL {
                        url = urlObject
                    } else if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                        print("Converted data to URL: \(String(describing: url))")
                    }
                    if let url = url {
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
                }
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                        DispatchQueue.main.async {
                            contextManager.addItem(.browserTab(browserTab), to: contextManager.contexts[contextIndex].id)
                        }
                    } else if let url = item as? URL {
                        let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                        DispatchQueue.main.async {
                            contextManager.addItem(.browserTab(browserTab), to: contextManager.contexts[contextIndex].id)
                        }
                    }
                }
                handled = true
                let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) ? UTType.text.identifier : UTType.plainText.identifier
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                    if let text = item as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                            DispatchQueue.main.async {
                                contextManager.addItem(.browserTab(browserTab), to: contextManager.contexts[contextIndex].id)
                                print("Added browser tab: \(browserTab.title)")
                            }
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) || provider.hasItemConformingToTypeIdentifier("public.url") {
                let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ? UTType.url.identifier : "public.url"
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                    if let error = error {
                        print("Error loading URL: \(error)")
                        return
                    }
                    var url: URL?
                    if let urlObject = item as? URL {
                        url = urlObject
                    } else if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                        print("Converted data to URL: \(String(describing: url))")
                    } else if let str = item as? String, let urlFromString = URL(string: str) {
                        url = urlFromString
                    }
                    if let url = url {
                        let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                        DispatchQueue.main.async {
                            contextManager.addItem(.browserTab(browserTab), to: contextManager.contexts[contextIndex].id)
                            print("Added browser tab: \(browserTab.title)")
                        }
                    }
                }
                handled = true
            }
        }
        print("Drop handling complete. Handled: \(handled)")
        return handled
    }
} 