import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit
import PhosphorSwift

// MARK: - Context Editor View

struct ContextEditorView: View {
    @ObservedObject var contextManager: ContextManager
    @Binding var selectedContextID: UUID?
    @State private var showDeleteAlert = false
    @State private var showAddAppDialog = false
    @State private var showAddDocumentDialog = false
    @State private var showAddBrowserTabDialog = false
    @State private var showAddTerminalDialog = false
    
    var selectedContext: Context? {
        contextManager.contexts.first(where: { $0.id == selectedContextID })
    }
    
    var body: some View {
        NavigationSplitView {
            ContextSidebarView(
                contextManager: contextManager,
                selectedContextID: $selectedContextID,
                showDeleteAlert: $showDeleteAlert
            )
        } detail: {
            ContextDetailsView(
                contextManager: contextManager,
                selectedContextID: $selectedContextID,
                showAddAppDialog: $showAddAppDialog,
                showAddDocumentDialog: $showAddDocumentDialog,
                showAddBrowserTabDialog: $showAddBrowserTabDialog,
                showAddTerminalDialog: $showAddTerminalDialog
            )
            .onDrop(of: [UTType.fileURL, UTType.url, UTType.text, UTType.plainText], isTargeted: nil) { providers in
                return handleUniversalDrop(providers: providers)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleUniversalDrop(providers: [NSItemProvider]) -> Bool {
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
                                // Add as application
                                if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                                    let appItem = AppItem(name: url.deletingPathExtension().lastPathComponent, bundleIdentifier: bundleId, windowTitle: nil)
                                    contextManager.contexts[contextIndex].applications.append(appItem)
                                    contextManager.saveContexts()
                                    print("Added application: \(appItem.name)")
                                }
                            } else {
                                // Add as document
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
                                contextManager.contexts[contextIndex].documents.append(document)
                                contextManager.saveContexts()
                                print("Added document: \(document.name)")
                            }
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                        DispatchQueue.main.async {
                            contextManager.contexts[contextIndex].browserTabs.append(browserTab)
                            contextManager.saveContexts()
                        }
                    } else if let url = item as? URL {
                        let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                        DispatchQueue.main.async {
                            contextManager.contexts[contextIndex].browserTabs.append(browserTab)
                            contextManager.saveContexts()
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) ? UTType.text.identifier : UTType.plainText.identifier
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                    if let text = item as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Try to parse as URL first
                        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            let browserTab = BrowserTab(title: url.absoluteString, url: url.absoluteString, browser: "default")
                            DispatchQueue.main.async {
                                contextManager.contexts[contextIndex].browserTabs.append(browserTab)
                                contextManager.saveContexts()
                                print("Added browser tab: \(browserTab.title)")
                            }
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

// MARK: - UI Components

struct CardSection: View {
    var title: String
    var items: [CardRow]
    var onAdd: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 18)
            HStack {
                Text(title)
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                if let onAdd = onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            VStack(spacing: 0) {
                if items.isEmpty {
                    HStack {
                        Spacer()
                        Text("No items")
                            .foregroundColor(.secondary)
                            .font(.body)
                        Spacer()
                    }
                    .frame(minHeight: 56)
                } else {
                    ForEach(items.indices, id: \.self) { idx in
                        items[idx]
                        if idx < items.count - 1 {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.vertical, 4)
    }
}

struct CardRow: View {
    var icon: String
    var title: String
    var subtitle: String?
    var onOpen: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                if let subtitle = subtitle {
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if let onOpen = onOpen {
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.plain)
                .help("Open")
            }
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
    }
}

// MARK: - Generic Dialog Component

struct GenericDialog<Content: View>: View {
    let title: String
    let content: Content
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let confirmTitle: String
    let isConfirmDisabled: Bool
    
    init(
        title: String,
        confirmTitle: String = "Add",
        isConfirmDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.isConfirmDisabled = isConfirmDisabled
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2).fontWeight(.bold)
                .padding(.bottom, 12)
            
            content
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button(confirmTitle) { onConfirm() }
                    .disabled(isConfirmDisabled)
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(width: 420, height: 340)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Dialog Content Views

struct AddAppDialogContent: View {
    enum Tab { case browse, running, manual }
    @State private var selectedTab: Tab = .browse
    @State private var manualName: String = ""
    @State private var manualBundle: String = ""
    @State private var manualWindowTitle: String = ""
    @State private var selectedRunningAppPIDs: Set<pid_t> = []
    @State private var browseAppName: String = ""
    @State private var browseBundle: String = ""
    @State private var browseWindowTitle: String = ""
    @State private var showOpenPanel = false
    var onAdd: (AppItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Method", selection: $selectedTab) {
                Text("Browse").tag(Tab.browse)
                Text("Running Apps").tag(Tab.running)
                Text("Manual").tag(Tab.manual)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 16)
            
            if selectedTab == .browse {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Choose Application...") {
                        showOpenPanel = true
                    }
                    if !browseAppName.isEmpty {
                        Text("Name: \(browseAppName)")
                        Text("Bundle ID: \(browseBundle)")
                        TextField("Window Title (optional)", text: $browseWindowTitle)
                    }
                }
            } else if selectedTab == .running {
                let runningApps = NSWorkspace.shared.runningApplications
                    .filter { $0.bundleIdentifier != nil && $0.activationPolicy == .regular }
                    .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
                List(runningApps, id: \.processIdentifier) { app in
                    HStack {
                        Text(app.localizedName ?? "Unknown")
                        Spacer()
                        Text(app.bundleIdentifier ?? "")
                        if selectedRunningAppPIDs.contains(app.processIdentifier) {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedRunningAppPIDs.contains(app.processIdentifier) {
                            selectedRunningAppPIDs.remove(app.processIdentifier)
                        } else {
                            selectedRunningAppPIDs.insert(app.processIdentifier)
                        }
                    }
                }
            } else if selectedTab == .manual {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("App Name", text: $manualName)
                    TextField("Bundle Identifier", text: $manualBundle)
                    TextField("Window Title (optional)", text: $manualWindowTitle)
                }
            }
        }
        .onChange(of: showOpenPanel) { oldValue, newValue in
            if newValue {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [UTType.application]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                if panel.runModal() == .OK, let url = panel.url {
                    if let bundle = Bundle(url: url),
                       let bundleId = bundle.bundleIdentifier {
                        browseAppName = url.deletingPathExtension().lastPathComponent
                        browseBundle = bundleId
                    } else {
                        browseAppName = url.deletingPathExtension().lastPathComponent
                        browseBundle = ""
                    }
                }
                showOpenPanel = false
            }
        }
    }
    
    func createAppItem() -> AppItem? {
        if selectedTab == .browse {
            return AppItem(name: browseAppName, bundleIdentifier: browseBundle, windowTitle: browseWindowTitle.isEmpty ? nil : browseWindowTitle)
        } else if selectedTab == .running {
            let runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.bundleIdentifier != nil && $0.activationPolicy == .regular }
                .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
            let selectedApps = runningApps.filter { selectedRunningAppPIDs.contains($0.processIdentifier) }
            if let app = selectedApps.first, let name = app.localizedName, let bundle = app.bundleIdentifier {
                return AppItem(name: name, bundleIdentifier: bundle, windowTitle: nil)
            }
        } else if selectedTab == .manual {
            return AppItem(name: manualName, bundleIdentifier: manualBundle, windowTitle: manualWindowTitle.isEmpty ? nil : manualWindowTitle)
        }
        return nil
    }
    
    var isConfirmDisabled: Bool {
        (selectedTab == .browse && (browseAppName.isEmpty || browseBundle.isEmpty)) ||
        (selectedTab == .running && selectedRunningAppPIDs.isEmpty) ||
        (selectedTab == .manual && (manualName.isEmpty || manualBundle.isEmpty))
    }
}

struct AddDocumentDialogContent: View {
    enum Tab { case browse, opened }
    @State private var selectedTab: Tab = .browse
    @State private var docName: String = ""
    @State private var docPath: String = ""
    @State private var docApp: String = ""
    @State private var showOpenPanel = false
    @State private var bookmark: Data? = nil
    var onAdd: (DocumentItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Method", selection: $selectedTab) {
                Text("Browse").tag(Tab.browse)
                Text("Opened Documents").tag(Tab.opened)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 16)
            
            if selectedTab == .browse {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Choose Document...") {
                        showOpenPanel = true
                    }
                    if !docPath.isEmpty {
                        Text("Name: \(docName)")
                        Text("Path: \(docPath)")
                        TextField("Application (optional)", text: $docApp)
                    }
                }
            } else if selectedTab == .opened {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No opened documents detected.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: showOpenPanel) { oldValue, newValue in
            if newValue {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                if panel.runModal() == .OK, let url = panel.url {
                    docName = url.deletingPathExtension().lastPathComponent
                    docPath = url.path
                    do {
                        bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    } catch {
                        bookmark = nil
                    }
                }
                showOpenPanel = false
            }
        }
    }
    
    func createDocumentItem() -> DocumentItem {
        return DocumentItem(name: docName, filePath: docPath, application: docApp.isEmpty ? "" : docApp, bookmark: bookmark)
    }
    
    var isConfirmDisabled: Bool {
        docName.isEmpty || docPath.isEmpty
    }
}

struct AddBrowserTabDialogContent: View {
    @State private var tabTitle: String = ""
    @State private var tabURL: String = ""
    @State private var selectedBrowser: String = "Default"
    
    let availableBrowsers = ["Safari", "Chrome", "Firefox", "Default"]
    var onAdd: (BrowserTab) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Tab Title", text: $tabTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("URL", text: $tabURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .placeholder(when: tabURL.isEmpty) {
                    Text("https://example.com")
                        .foregroundColor(.secondary)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Browser")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Browser", selection: $selectedBrowser) {
                    ForEach(availableBrowsers, id: \.self) { browser in
                        Text(browser).tag(browser)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    func createBrowserTab() -> BrowserTab {
        let browser = selectedBrowser == "Default" ? "default" : selectedBrowser
        return BrowserTab(
            title: tabTitle.isEmpty ? tabURL : tabTitle,
            url: tabURL,
            browser: browser
        )
    }
    
    var isConfirmDisabled: Bool {
        tabURL.isEmpty
    }
}

// MARK: - Dialog Wrappers

struct AddAppDialog: View {
    var onAdd: (AppItem) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GenericDialog(
            title: "Add Application",
            onCancel: onCancel,
            onConfirm: {
                let content = AddAppDialogContent(onAdd: onAdd)
                if let appItem = content.createAppItem() {
                    onAdd(appItem)
                }
            }
        ) {
            AddAppDialogContent(onAdd: onAdd)
        }
    }
}

struct AddDocumentDialog: View {
    var onAdd: (DocumentItem) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GenericDialog(
            title: "Add Document",
            onCancel: onCancel,
            onConfirm: {
                let content = AddDocumentDialogContent(onAdd: onAdd)
                onAdd(content.createDocumentItem())
            }
        ) {
            AddDocumentDialogContent(onAdd: onAdd)
        }
    }
}

struct AddBrowserTabDialog: View {
    var onAdd: (BrowserTab) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GenericDialog(
            title: "Add Browser Tab",
            onCancel: onCancel,
            onConfirm: {
                let content = AddBrowserTabDialogContent(onAdd: onAdd)
                onAdd(content.createBrowserTab())
            }
        ) {
            AddBrowserTabDialogContent(onAdd: onAdd)
        }
    }
}

struct EditableContextName: View {
    @State private var isEditing = false
    @State private var draftName: String
    var name: String
    var onCommit: (String) -> Void
    
    init(name: String, onCommit: @escaping (String) -> Void) {
        self.name = name
        self.onCommit = onCommit
        _draftName = State(initialValue: name)
    }
    
    var body: some View {
        Group {
            if isEditing {
                TextField("Context Name", text: $draftName, onCommit: {
                    isEditing = false
                    if !draftName.trimmingCharacters(in: .whitespaces).isEmpty && draftName != name {
                        onCommit(draftName)
                    }
                })
                .font(.system(size: 28, weight: .bold))
                .textFieldStyle(PlainTextFieldStyle())
                .onAppear { DispatchQueue.main.async { self.isEditing = true } }
                .onExitCommand { isEditing = false }
                .onSubmit {
                    isEditing = false
                    if !draftName.trimmingCharacters(in: .whitespaces).isEmpty && draftName != name {
                        onCommit(draftName)
                    }
                }
            } else {
                Text(name)
                    .font(.system(size: 28, weight: .bold))
                    .onTapGesture { 
                        draftName = name
                        isEditing = true 
                    }
            }
        }
        .frame(minWidth: 120, alignment: .leading)
        .onChange(of: name) { oldValue, newName in
            isEditing = false
            draftName = newName
        }
    }
}

// MARK: - Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct ContextCardView: View {
    let context: Context
    let isSelected: Bool
    let onSelect: () -> Void
    let onIconChange: (String?, String?, String?) -> Void
    
    @State private var isHovered = false
    @State private var showIconSelector = false
    
    var iconColor: Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .teal]
        let idx = abs(context.name.hashValue) % colors.count
        return colors[idx]
    }
    
    var foregroundColor: Color {
        if let foregroundHex = context.iconForegroundColor, let color = Color(hex: foregroundHex) {
            return color
        } else {
            return iconColor
        }
    }
    
    var itemCountText: String {
        let total = context.applications.count + context.documents.count + context.browserTabs.count + context.terminalSessions.count
        return "\(total) items"
    }
    
    var backgroundColor: Color {
        if isSelected {
            if let backgroundColorHex = context.iconBackgroundColor, let backgroundColor = Color(hex: backgroundColorHex) {
                return backgroundColor.darker(by: 0.25)
            } else {
                return Color.accentColor.opacity(0.32)
            }
        } else if isHovered {
            return Color.accentColor.opacity(0.12)
        } else {
            return Color.clear
        }
    }

    // Adaptive label color for best contrast
    var adaptiveLabelColor: Color {
        let bg: Color = backgroundColor
        // Try icon foreground color if set and not too close to background
        if let foregroundHex = context.iconForegroundColor, let fg = Color(hex: foregroundHex), fg.contrastRatio(with: bg) > 2.5, fg != bg {
            return fg
        }
        // Otherwise, pick black or white for best contrast
        let blackContrast = Color.black.contrastRatio(with: bg)
        let whiteContrast = Color.white.contrastRatio(with: bg)
        return blackContrast > whiteContrast ? .black : .white
    }
    
    var borderColor: Color {
        isSelected ? Color.accentColor : Color(NSColor.separatorColor)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon
            Group {
                ZStack {
                    if let backgroundColorHex = context.iconBackgroundColor, let backgroundColor = Color(hex: backgroundColorHex) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(backgroundColor)
                            .frame(width: 32, height: 32)
                    }
                    if let iconName = context.iconName, let icon = Ph(rawValue: iconName) {
                        icon.regular
                            .font(.title2)
                            .foregroundColor(foregroundColor)
                    } else {
                        Image(systemName: "folder")
                            .font(.title2)
                            .foregroundColor(foregroundColor)
                    }
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.6)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(itemCountText)
                    .font(.footnote)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture { onSelect() }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Change Icon...") {
                showIconSelector = true
            }
        }
        .sheet(isPresented: $showIconSelector) {
            IconSelectorView(
                selectedIconName: context.iconName,
                selectedIconBackgroundColor: context.iconBackgroundColor,
                selectedIconForegroundColor: context.iconForegroundColor,
                onSelect: { iconName, backgroundColorHex, foregroundColorHex in
                    onIconChange(iconName, backgroundColorHex, foregroundColorHex)
                    showIconSelector = false
                },
                onCancel: {
                    showIconSelector = false
                }
            )
        }
    }
}

// MARK: - Icon Selector View

struct IconSelectorView: View {
    let selectedIconName: String?
    let selectedIconBackgroundColor: String?
    let selectedIconForegroundColor: String?
    let onSelect: (String?, String?, String?) -> Void
    let onCancel: () -> Void
    
    @State private var searchText = ""
    @State private var selectedIcon: String?
    @State private var selectedBackgroundColor: Color = .clear
    @State private var selectedForegroundColor: Color = .black
    @State private var hasCustomBackgroundColor: Bool = false
    @State private var hasCustomForegroundColor: Bool = false
    
    // Predefined colors
    private let pastelColors: [Color] = [
        Color(red: 1.0, green: 0.8, blue: 0.8), // Light pink
        Color(red: 1.0, green: 0.6, blue: 0.8), // Pink
        Color(red: 0.9, green: 0.7, blue: 1.0), // Light purple
        Color(red: 0.8, green: 0.8, blue: 1.0), // Light blue
        Color(red: 0.7, green: 0.8, blue: 1.0), // Sky blue
        Color(red: 0.8, green: 1.0, blue: 1.0), // Light cyan
        Color(red: 0.8, green: 1.0, blue: 0.8), // Light green
        Color(red: 1.0, green: 1.0, blue: 0.8), // Light yellow
        Color(red: 1.0, green: 0.9, blue: 0.8), // Peach
        Color(red: 1.0, green: 0.7, blue: 0.7), // Light red
        Color(red: 1.0, green: 0.8, blue: 0.9), // Rose
        Color(red: 0.9, green: 0.8, blue: 0.9), // Lavender
        Color(red: 0.8, green: 0.9, blue: 0.9), // Mint
        Color(red: 0.9, green: 0.9, blue: 0.8), // Cream
        Color(red: 0.8, green: 0.8, blue: 0.9), // Periwinkle
        Color(red: 0.9, green: 0.8, blue: 0.8), // Salmon
        Color(red: 0.9, green: 0.9, blue: 0.9)  // Light gray
    ]
    
    private let foregroundColors: [Color] = [
        .black,    // Black
        .white,    // White
        Color(red: 0.2, green: 0.2, blue: 0.2), // Dark gray
        Color(red: 0.8, green: 0.8, blue: 0.8), // Light gray
        Color(red: 0.8, green: 0.2, blue: 0.2), // Dark red
        Color(red: 0.2, green: 0.6, blue: 0.2), // Dark green
        Color(red: 0.2, green: 0.2, blue: 0.8), // Dark blue
        Color(red: 0.6, green: 0.2, blue: 0.8), // Purple
        Color(red: 0.8, green: 0.6, blue: 0.2), // Orange
        Color(red: 0.8, green: 0.2, blue: 0.6), // Magenta
        Color(red: 0.2, green: 0.8, blue: 0.8), // Teal
        Color(red: 0.6, green: 0.8, blue: 0.2), // Lime
        Color(red: 0.8, green: 0.8, blue: 0.2), // Yellow
        Color(red: 0.4, green: 0.4, blue: 0.4), // Medium gray
        Color(red: 0.6, green: 0.6, blue: 0.6), // Light gray
        Color(red: 0.9, green: 0.9, blue: 0.9), // Very light gray
        Color(red: 0.1, green: 0.1, blue: 0.1)  // Very dark gray
    ]
    
    private var filteredIcons: [String] {
        if searchText.isEmpty {
            return Ph.allCases.map { $0.rawValue }
        } else {
            return Ph.allCases
                .map { $0.rawValue }
                .filter { $0.localizedCaseInsensitiveContains(searchText) }
                .map { $0 }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search icons...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                Spacer()
                Text("\(filteredIcons.count) icons")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
            
            // Icon grid
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                        // Default icon
                        IconGridItem(
                            iconName: nil,
                            isSelected: selectedIcon == nil,
                            hasCustomBackgroundColor: hasCustomBackgroundColor,
                            selectedBackgroundColor: selectedBackgroundColor,
                            hasCustomForegroundColor: hasCustomForegroundColor,
                            selectedForegroundColor: selectedForegroundColor,
                            onTap: { selectedIcon = nil }
                        )
                        .id("default")
                        
                        // Icon options
                        ForEach(filteredIcons, id: \.self) { iconName in
                            IconGridItem(
                                iconName: iconName,
                                isSelected: selectedIcon == iconName,
                                hasCustomBackgroundColor: hasCustomBackgroundColor,
                                selectedBackgroundColor: selectedBackgroundColor,
                                hasCustomForegroundColor: hasCustomForegroundColor,
                                selectedForegroundColor: selectedForegroundColor,
                                onTap: { selectedIcon = iconName }
                            )
                            .id(iconName)
                        }
                    }
                    .padding(20)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let selectedIconName = selectedIconName {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(selectedIconName, anchor: .center)
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("default", anchor: .center)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Color selection sections
            ColorSelectionSection(
                title: "Foreground:",
                colors: foregroundColors,
                selectedColor: $selectedForegroundColor,
                hasCustomColor: $hasCustomForegroundColor
            )
            
            Divider()
            
            ColorSelectionSection(
                title: "Background:",
                colors: pastelColors,
                selectedColor: $selectedBackgroundColor,
                hasCustomColor: $hasCustomBackgroundColor,
                isBackground: true
            )
            
            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Select") {
                    let backgroundHex = hasCustomBackgroundColor ? selectedBackgroundColor.toHexString() : nil
                    let foregroundHex = hasCustomForegroundColor ? selectedForegroundColor.toHexString() : nil
                    onSelect(selectedIcon, backgroundHex, foregroundHex)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIcon == selectedIconName && 
                         (!hasCustomBackgroundColor || selectedBackgroundColor.toHexString() == selectedIconBackgroundColor) &&
                         (!hasCustomForegroundColor || selectedForegroundColor.toHexString() == selectedIconForegroundColor))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 700, height: 540)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            selectedIcon = selectedIconName
            if let hex = selectedIconBackgroundColor, let color = Color(hex: hex) {
                selectedBackgroundColor = color
                hasCustomBackgroundColor = true
            } else {
                selectedBackgroundColor = .clear
                hasCustomBackgroundColor = false
            }
            
            if let hex = selectedIconForegroundColor, let color = Color(hex: hex) {
                selectedForegroundColor = color
                hasCustomForegroundColor = true
            } else {
                selectedForegroundColor = .black
                hasCustomForegroundColor = false
            }
        }
        .onChange(of: selectedBackgroundColor) { _, newColor in
            hasCustomBackgroundColor = newColor != .clear
        }
    }
}

// MARK: - Reusable Components

struct IconGridItem: View {
    let iconName: String?
    let isSelected: Bool
    let hasCustomBackgroundColor: Bool
    let selectedBackgroundColor: Color
    let hasCustomForegroundColor: Bool
    let selectedForegroundColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    if hasCustomBackgroundColor {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedBackgroundColor)
                            .frame(width: 40, height: 40)
                    }
                    if let iconName = iconName, let icon = Ph(rawValue: iconName) {
                        icon.regular
                            .font(.title2)
                            .foregroundColor(hasCustomForegroundColor ? selectedForegroundColor : .primary)
                    } else {
                        Image(systemName: "folder")
                            .font(.title2)
                            .foregroundColor(hasCustomForegroundColor ? selectedForegroundColor : .blue)
                    }
                }
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
            }
        }
        .buttonStyle(.plain)
    }
}

struct ColorSelectionSection: View {
    let title: String
    let colors: [Color]
    @Binding var selectedColor: Color
    @Binding var hasCustomColor: Bool
    let isBackground: Bool
    
    init(
        title: String,
        colors: [Color],
        selectedColor: Binding<Color>,
        hasCustomColor: Binding<Bool>,
        isBackground: Bool = false
    ) {
        self.title = title
        self.colors = colors
        self._selectedColor = selectedColor
        self._hasCustomColor = hasCustomColor
        self.isBackground = isBackground
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .trailing)
                .lineLimit(1)
            
            HStack(spacing: 6) {
                ForEach(colors, id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                        hasCustomColor = isBackground ? color != .clear : true
                    }) {
                        Circle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.blue : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                // Custom color option
                Button(action: {
                    let coordinator = isBackground ? BackgroundColorPanelCoordinator.shared : ForegroundColorPanelCoordinator.shared
                    coordinator.onColorChanged = { color in
                        selectedColor = color
                        hasCustomColor = true
                    }
                    coordinator.showColorPanel(initialColor: selectedColor)
                }) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Unified Color Panel Coordinator

class ColorPanelCoordinator: NSObject {
    var onColorChanged: ((Color) -> Void)?
    private var colorPanel: NSColorPanel?
    
    func showColorPanel(initialColor: Color) {
        colorPanel = NSColorPanel()
        colorPanel?.color = NSColor(initialColor)
        colorPanel?.setTarget(self)
        colorPanel?.setAction(#selector(colorChanged))
        colorPanel?.makeKeyAndOrderFront(nil)
    }
    
    @objc func colorChanged() {
        guard let colorPanel = colorPanel else { return }
        let newColor = Color(colorPanel.color)
        onColorChanged?(newColor)
    }
    
    func closeColorPanel() {
        colorPanel?.close()
        colorPanel = nil
    }
}

class ForegroundColorPanelCoordinator: ColorPanelCoordinator {
    static let shared = ForegroundColorPanelCoordinator()
}

class BackgroundColorPanelCoordinator: ColorPanelCoordinator {
    static let shared = BackgroundColorPanelCoordinator()
}


