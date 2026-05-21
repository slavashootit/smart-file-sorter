# ADR 0004: Configuration Management via ConfigManager

## Status
Accepted

## Context
Configuration rules (file exclusions, folder categories, extension lists) in earlier versions were either hardcoded inside the engine or scattered across multiple components. There was no easy, structured way for the user to customize exclusions or sorting categories. Additionally, confirmation dialogs (e.g., during folder cleanup) relied on blocking AppKit modals (`NSAlert().runModal()`), which froze the main thread and violated modern UI guidelines.

## Decision
We introduced a centralized `ConfigManager` to handle configuration persistence:
1. **JSON Configuration Files**:
   - `exclusions.json`: Defines custom paths, extensions, or names to exclude from sorting.
   - `categories.json`: Maps categories (e.g., Images, Documents, Videos) to lists of extensions.
2. **SwiftUI Sheets**: Created `ExclusionsEditorSheet` and `CategoriesEditorSheet` to let the user add, edit, and remove settings directly from the application's preferences tab.
3. **Non-blocking Dialogs**: Replaced AppKit's `NSAlert().runModal()` in `CleanupView.swift` with SwiftUI's native, non-blocking `.confirmationDialog()` to keep the app responsive during deletion prompts.

## Consequences
- **User Flexibility**: Users can completely customize which file types belong to which folder and specify custom files/directories to ignore (like `.DS_Store` or local build folders).
- **Architecture Separation**: The UI and engine do not contain hardcoded lists; they dynamically query `ConfigManager`.
- **Fluid User Experience**: Removing blocking modals guarantees the rendering pipeline remains uninterrupted.
