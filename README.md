# Flitro

Flitro is a macOS productivity app that lets you quickly switch between different work contexts (sets of apps, documents, browser tabs, and terminal sessions) with a single click. It features a modern SwiftUI interface, a menu bar icon for quick access, and robust single-window management.

## Features

- **Context Management:** Create, edit, and delete named contexts, each containing apps, documents, browser tabs, and terminal sessions.
- **One-Click Switching:** Instantly switch your workspace to a saved context, with support for multiple switching modes (Replace All, Additive, Hybrid).
- **Menu Bar Integration:** Access all your contexts and switch modes directly from the macOS menu bar.
- **Single Window:** The main window is always reused and never duplicated. Closing the window hides it; you can reopen it from the menu bar or via keyboard shortcut.
- **Modern UI:** Built with SwiftUI and AppKit for the best of both worlds. Supports unified toolbar and sidebar.

## Requirements

- macOS 15 or later
- Xcode 15 or later
- Swift 5.9+

## Installation

1. Clone the repository:
   ```sh
   git clone https://github.com/yourusername/Flitro.git
   cd Flitro
   ```
2. Open `Flitro.xcodeproj` in Xcode.
3. Build and run the app (⌘R).

## Usage

- **Configure Contexts:** Open the main window ("Configure" from the menu bar or ⌘0) to add, edit, or remove contexts.
- **Switch Contexts:** Use the menu bar icon to select a context and a switching mode. The app will open/close apps, documents, browser tabs, and terminals as defined.
- **Hide/Show Main Window:** Closing the main window hides it. Use the menu bar "Configure" item or ⌘0 to bring it back.
- **Quit:** Use the menu bar or standard macOS quit command (⌘Q).

## Development Notes

- The app uses a hybrid SwiftUI + AppKit approach for robust window management and modern UI.
- The main window is managed by SwiftUI's `WindowGroup` for toolbar/sidebar support, but close events are intercepted in the AppDelegate to hide instead of close.
- The menu bar uses `MenuBarExtra` and observes the shared `ContextManager` for live updates.
- All state is managed via a singleton `ContextManager` injected as an `@EnvironmentObject`.

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License

See [LICENSE](LICENSE) for details. 