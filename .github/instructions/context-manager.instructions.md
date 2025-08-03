---
description: Architectural rules for any modification of ContextManager.swift
applyTo: 'ContextManager.swift'
---
# ContextManager Architecture Instruction

## Core Principles
- `ContextManager.swift` must remain completely independent of UI code. Never import SwiftUI or any UI-related frameworks.
- ContextManager must track all applications, documents, and windows it opens for a context, so it can close them correctly when the context is closed.

## Allowed Imports
- Only import `Foundation` (basic data types, file operations, system APIs).
- Only import `AppKit` (workspace management, application control, system-level operations).

## Forbidden Imports
- Never import `SwiftUI` or any UI frameworks.
- Never import custom UI components, views, or UI-related extensions/utilities.

## Data Models
- All data models must be pure Swift structs, conforming to `Codable`, `Equatable`, and `Hashable`.
- Data models must be independent of any UI representation.
- Data models must be serializable to JSON for persistence.
- No references to UI types (e.g., `Color`, `Font`, view modifiers).

## ObservableObject Pattern
- You may use `@Published` properties for reactive updates.
- UI components should observe ContextManager, not the other way around.
- No direct UI state management within ContextManager.

## Application Management
- Only perform system-level operations (launching/closing apps, file operations).
- No UI-specific application state tracking.
- Use `NSWorkspace` for application control, not UI frameworks.

## Persistence
- Use `FileManager` and `JSONEncoder`/`JSONDecoder` for data persistence.
- No UI-specific storage mechanisms.
- File paths and data formats must be UI-independent.

## Testing
- ContextManager must be testable without UI dependencies.
- Mock data and test scenarios must not require UI setup.
- Unit tests should focus on business logic, not UI behavior.

## Examples
❌ DON'T:
```swift
import SwiftUI  // Forbidden in ContextManager
struct Context {
    var uiColor: Color  // UI-specific property
    var font: Font      // UI-specific property
}
```

✅ DO:
```swift
import Foundation
import AppKit
struct Context {
    var name: String
    var applications: [AppItem]
    // Pure data, no UI references
}
```

## Integration Pattern
UI components should:
1. Create a `@StateObject` or `@ObservedObject` ContextManager instance
2. Subscribe to published properties for reactive updates
3. Call ContextManager methods for business operations
4. Handle UI-specific concerns separately from business logic

This ensures ContextManager remains a pure business logic layer, reusable across different UI implementations or non-UI contexts.
