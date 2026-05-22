# Changelog

All notable changes to the **Smart File Sorter** project will be documented in this file.

---

## [1.6.0] - 2026-05-21

### Added
- **Redesigned SortingView** — Rebuilt the main sorting view into a 4-zone vertical stack: Zone A (`DropZoneView`), Zone B (`FilterBarView`), Zone C (Action / Progress row), and Zone D (`LastRunSummaryView`).
- **Sidebar Consolidation** — Consolidated Duplicates, Similar Photos, and Cleanup under a single expandable `DisclosureGroup` titled "Прибирання" with trash icon, default-expanded, bound to `@AppStorage` for persistence.
- **App Menu "About"** — Added standard macOS App Menu button "Про Smart File Sorter" to post a `"ShowAboutView"` notification that switches the view to the About tab.
- **Polish Components** — Integrated `MagneticButton`, `Ripple`, `AnimatedNumber`, `BentoStat` sparklines, and `FilmGrain` overlay on `MeshBackground`.

### Changed
- **Last Run Metrics** — Removed simulated duration; added Ukrainian relative timestamp (e.g., "сьогодні 14:23", "вчора 21:29") along with file count and source folder name.
- **Disk Analyzer** — Removed the "NEW" badge from the sidebar link for "Аналізатор диска".
- **About Tab Navigation** — Removed "Про програму" navigation link from the sidebar list entirely; it is now hidden and only reachable via the macOS App Menu.
- **Design Discipline** — Unified accent color scheme across the application and charts (`DT.Color.accent` family), completely removing purple/pink ("AI-lila") colors.
- **DropZoneView Path Formatting** — Fixed deep folder path representation bug, ensuring `~/` is preserved for home-relative deep paths.

---

## [1.5.1] - 2026-05-21

### Removed
- **Profile system** — `ProfileManager`, `Profile` struct, profile picker from sidebar and menu bar, `activeProfile`/`currentProfile` properties from all files.
- **Semantic Search** — `SemanticSearchView`, `SemanticSearchEngine`, embeddings SQLite table, sidebar nav link, route case.
- **`BatchRecord.profileName`** field — removed from model, SQLite column (`ALTER TABLE DROP COLUMN`), INSERT/SELECT queries, CSV export.
- `NLContextualEmbedding` — not used anywhere (0 callsites).

### Changed
- `rules_Home.json` renamed to `rules.json` (migrated on launch via `FileManager.moveItem`).
- `watcher_paths_Home` UserDefault renamed to `watcher_paths` (migrated on first launch, old key removed).
- CSV export header: removed "Профіль" column.

### Notes
- Legacy `profiles.json` files on disk are silently ignored.
- All migration code references legacy key names only to read-and-delete them.
- `grep -rin "profile" Sources/` returns 0 runtime results (only migration SQL).

---

## [1.5.0] - 2026-05-21

This release delivers the **v1.5 "Visual Identity"** milestone, implementing a premium, modern design system throughout the entire application with unified design tokens, dynamic animations, and accessibility-first motion controls.

### Added
- **Design Tokens System**: Introduced unified spacing, radius tokens, spring animation curves, and a custom dark mode color palette (`DT` enum in `DesignSystem.swift`).
- **Canvas-based Mesh Background**: Added a fluid, multi-blob dynamic mesh gradient background (`MeshBackground.swift`) that runs under the entire interface.
- **Liquid Glass modifier**: Created a unified glassmorphism styling modifier (`.liquidGlass()`) and applied it to cards, containers, sidebar, and popovers across all 12 views.
- **Spotlight Hover modifier**: Implemented an interactive mouse-tracking spotlight radial gradient overlay (`.spotlightHover()`) for sidebar navigation items and card hover states.
- **Animated Status Pill**: Created `StatusPill.swift` to present desaturated, pulsing indicators of the current application state.
- **Shimmer Progress Indicator**: Implemented a modern shimmering animation overlay (`.shimmer()`) for active progress bars.
- **Log Slide-in Transitions**: Integrated spring-based asymmetric slide-in transitions for terminal log outputs in the main view console.
- **Sidebar Notification Badges**: Added live notification badges (`NavBadge.swift`) in the sidebar, displaying a live duplicates count, "AI" label for semantic searches, and "NEW" badge for disk analyzer.
- **Accessibility Motion Reduction**: Full support for system-wide `@Environment(\.accessibilityReduceMotion)`, which seamlessly disables mesh animations, pulsing effects, log transitions, and shimmers.

### Changed
- **Forced Dark Mode**: Programmatically locked the application to dark appearance at the root window level.
- **Swift Concurrency Audit**: Refactored `DuplicateFinder` to utilize task group return values instead of shared state locking (`NSLock`/`OSAllocatedUnfairLock`), completely eliminating Swift 6 concurrency warnings and potential deadlocks.
- **Modern AVKit Loading APIs**: Resolved macOS 13+ deprecation warnings by replacing synchronous `naturalSize` and `duration` AVURLAsset property reads with modern async-load alternatives (`loadTracks(withMediaType:)`, `load(.naturalSize)`, and `load(.duration)`).

---

## [1.4.0] - 2026-05-21

This release marks the **v1.4 "Consolidation"** stage, migrating the application to a pure Native Swift/SwiftUI core codebase on macOS, while archiving the legacy Python implementation as an automation fallback.

### Added
- **Native Swift Engine**: Fully functional macOS app written in Swift 5.9 and SwiftUI.
- **SQLite History Storage**: Replaced JSON history (`history.json`/`last_session.json`) with `history.db` powered by SQLite for transaction safety and high-performance querying.
- **XXHash64 Integration**: Built-in XXHash64 hash calculator for ultra-fast, multi-pass duplicate detection.
- **Async Concurrency**: Rebuilt sorting operation on `async/await` and `AsyncStream` with cooperative cancellation support and custom back-pressure throttling (`.bufferingNewest(100)`).
- **Persistent Cache**: Introduced `hash_cache.db` (SQLite) with automatic 30-day eviction of stale files to speed up subsequent scans by up to 78%.
- **ConfigManager**: Centralized configuration management using customizable `exclusions.json` and `categories.json`.
- **UI Editing Sheets**: Interactive exclusion/category editors added inside the Settings panel.
- **Native Confirmation Dialogs**: Replaced AppKit `NSAlert().runModal()` blocks with modern SwiftUI `.confirmationDialog()`.
- **Test Suite**: Converted all test files to structured `XCTestCase` tests and integrated them with GitHub Actions.
- **CI Pipeline**: Added `.github/workflows/ci.yml` targeting macOS 15 and Xcode 16.3 with automated building, parallel testing, and coverage check (minimum 60% on models).
- **Benchmark Suite**: Added `tools/benchmark.swift` to measure file scanning and hashing performance.

### Changed
- **Repository Reorganization**: Cleaned up the root directory by moving all legacy Python script files, Web UI assets, and spec sheets to the `/python/` directory.
- **Performance Fixes**:
  - Offloaded Spotlight metadata reading and AVURLAsset analysis from main-thread rendering loops into asynchronous tasks.
  - Implemented state-based statistics caching to eliminate redundant database checks in `DashboardView`.
  - Refactored angle mutations inside `SunburstChartView` to eliminate recursive layout calls.

### Removed
- **MD5/CryptoKit**: Completely removed MD5 hashing and Apple's `CryptoKit` from Swift sources to simplify the dependency tree.
