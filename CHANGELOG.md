# Changelog

All notable changes to the **Smart File Sorter** project will be documented in this file.

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
