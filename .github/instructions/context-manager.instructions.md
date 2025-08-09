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
- Data models may be Swift classes or structs, as appropriate for reactivity and architecture.
- Data models must conform to `Codable`, `Equatable`, and `Hashable` where possible.
- Data models may conform to `ObservableObject` and use `@Published` for properties that need to be observed by the UI.
- Data models must be independent of any UI representation.
- Data models must be serializable to JSON for persistence.
- No references to UI types (e.g., `Color`, `Font`, view modifiers).

## ObservableObject Pattern
- You may use `@Published` properties for reactive updates.
- Data models may conform to `ObservableObject` for fine-grained observation.
- UI components should observe ContextManager and/or individual data models, not the other way around.
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
class Context {
    var uiColor: Color  // UI-specific property
    var font: Font      // UI-specific property
}
```

✅ DO:
```swift
import Foundation
import AppKit
class Context: ObservableObject, Codable, Equatable, Hashable {
    @Published var name: String
    @Published var applications: [AppItem]
    // Pure data, no UI references
    // ...
}
```

## Integration Pattern
UI components should:
1. Create a `@StateObject` or `@ObservedObject` ContextManager instance
2. Subscribe to published properties for reactive updates
3. Call ContextManager methods for business operations
4. Handle UI-specific concerns separately from business logic

This ensures ContextManager remains a pure business logic layer, reusable across different UI implementations or non-UI contexts.
