import SwiftUI
import AppKit

// MARK: - Custom menubar popover UI (moved from FlitroApp.swift for maintainability)
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    override init() {
        super.init()
        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        // Use SF Symbol to ensure template rendering in the menu bar
        button.image = NSImage(systemSymbolName: "rectangle.3.offgrid", accessibilityDescription: "Flitro")
        button.image?.isTemplate = true
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.contentViewController = NSHostingController(rootView:
            ContextPickerPopoverView().environmentObject(ContextManager.shared)
        )
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

private struct ContextPickerPopoverView: View {
    @EnvironmentObject var contextManager: ContextManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image("AboutAppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .opacity(0.9)
                Text("Flitro")
                    .font(.headline)
                Spacer()
                Button(action: { showMainWindow() }) {
                    Image(systemName: "rectangle.and.text.magnifyingglass")
                }
                .focusEffectDisabled()
                .buttonStyle(HeaderIconButtonStyle())
                .help("Show Flitro")
                Button(action: { openSettings() }) {
                    Image(systemName: "gearshape")
                }
                .focusEffectDisabled()
                .buttonStyle(HeaderIconButtonStyle())
                .help("Settings")
                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "power")
                }
                .focusEffectDisabled()
                .buttonStyle(HeaderIconButtonStyle())
                .help("Quit")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                VisualEffectView(material: .menu, blendingMode: .behindWindow, emphasized: true)
                    .edgesIgnoringSafeArea(.top)
            )

            Divider()

            // Context list (single column)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(contextManager.contexts, id: \.reactiveId) { context in
                        ContextCardView(
                            context: context,
                            isSelected: false // No selection in popup
                        )
                        .environmentObject(contextManager)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                        .onTapGesture {
                            if contextManager.isActive(contextID: context.id) {
                                contextManager.closeContext(contextID: context.id)
                            } else {
                                contextManager.openContext(contextID: context.id)
                            }
                        }
                    }
                }
                .padding(8)
            }.background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 300, height: 520)
    }
}

// Header icon buttons: light gray by default, accent on hover/press, no background
private struct HeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HeaderIconButton(configuration: configuration)
    }

    private struct HeaderIconButton: View {
        let configuration: Configuration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 15, weight: .light))
                    .foregroundColor((isHovering || configuration.isPressed) ? .accentColor : Color.secondary)
                .contentShape(Rectangle())
                .onHover { isHovering = $0 }
        }
    }
}

// AppKit blur background helper for a subtle header
private struct VisualEffectView: NSViewRepresentable {
    typealias NSViewType = NSVisualEffectView

    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let emphasized: Bool

    func makeNSView(context: NSViewRepresentableContext<VisualEffectView>) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = emphasized
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: NSViewRepresentableContext<VisualEffectView>) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = emphasized
        nsView.state = .active
    }
}
