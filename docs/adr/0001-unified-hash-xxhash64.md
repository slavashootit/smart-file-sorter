# ADR 0001: Unified Hash Engine using XXHash64

## Status
Accepted

## Context
Previously, `SmartFileSorter` used multiple hashing algorithms for different features:
- The `DuplicateFinder` component used `XXHash64` (a fast non-cryptographic hash) to perform multi-pass checks (comparing file sizes, quick hashes, and then full hashes).
- The `SorterEngine` component used `MD5` via Apple's `CryptoKit` to detect file integrity and handle file cataloging.

Using multiple hashing algorithms was redundant, increased compilation dependencies, and led to code duplication. Furthermore, `MD5` is slow compared to `XXHash64` and is cryptographically compromised (although security is not a primary concern for file sorting, performance is critical).

## Decision
We standardized the entire hashing infrastructure on `XXHash64`:
1. We removed all dependencies on `CryptoKit` and all usages of `MD5` (both in code and string literals) from the codebase.
2. We added unified static helpers `hash(_:)` and `hashOfFile(at:)` directly inside `XXHash64.swift` (leveraging a clean Swift port of XXHash64).
3. The `SorterEngine` was refactored to reuse the same two-pass hashing strategy as `DuplicateFinder` to prevent duplicate scanning.

## Consequences
- **Performance**: Standardizing on `XXHash64` speeds up hashing of large files significantly compared to MD5.
- **Maintainability**: Unified code logic for hashing reduces codebase complexity and potential bugs in duplicate/original detection.
- **Binary Size & Build Speed**: Removing `CryptoKit` imports simplifies modular builds, improving overall compilation time and keeping dependencies minimal.
