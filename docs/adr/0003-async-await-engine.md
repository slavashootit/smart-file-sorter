# ADR 0003: Asynchronous Swift Concurrency Sorting Engine

## Status
Accepted

## Context
In previous versions, file sorting was executed synchronously. For large folders containing thousands of files, this blocked the main GUI thread, causing the application to freeze (generating beachballs) and preventing the user from interacting with the app or canceling the operation. Furthermore, cancellation support was either absent or unsafe, potentially leaving files in an untracked, partially moved state.

## Decision
We redesigned `SorterEngine` to run asynchronously using Swift's `async/await` paradigm:
1. **Asynchronous Stream**: `SorterEngine.sortFiles` was rewritten to return an `AsyncStream<SortProgress>`. This allows the GUI to consume progress updates asynchronously in a `.task` environment.
2. **Back-Pressure Handling**: The stream is configured with `.bufferingNewest(100)` buffering policy. This ensures that even if file processing is extremely rapid, the main thread queue is not flooded with UI updates, keeping the GUI responsive and smooth.
3. **Cooperative Cancellation**: At the start of each file move loop, the engine calls `Task.checkCancellation()`. If a cancel request is detected, the loop terminates immediately.
4. **Interrupted Batch Semantics**: When sorting is cancelled, the engine does not perform a blocking, synchronous roll back of the already-moved files. Instead, it commits the partially processed files to the SQLite history database as a valid batch flagged with `is_cancelled = 1`. The user can later trigger a standard rollback (Undo) via the History view at their own discretion.

## Consequences
- **Responsive GUI**: The app interface remains 100% fluid, even during sorting operations involving millions of files.
- **Robust Cancellation**: Canceling is instantaneous, safe, and does not require complex UI lockup. Files that were already moved remain cataloged in the database and can be reverted cleanly using the existing Undo system.
- **Code Cleanliness**: Leveraging native Swift structured concurrency avoids legacy dispatch queues and callback-based architectures.
