# Product Backlog — Smart File Sorter

## Milestone: v1.7.0 "Smart Scan"

The goal of the v1.7.0 milestone is to introduce intelligent automation and proactive file optimization capabilities, transitioning the application from a manual sorter/cleaner into a proactive file management assistant.

### Feature 1: Proactive Organization Suggestions
- **Goal**: Automatically scan the user's home folders or active watch paths for unorganized file clusters.
- **Mechanism**:
  - Background analyzer checking watch folders when system is idle.
  - Suggesting rule templates (e.g. "We noticed 15 documents in Downloads. Sort them now?").
- **UI Component**: A subtle dashboard card/toast showing proactive recommendations.

### Feature 2: Rule Association Learning (ML)
- **Goal**: Learn how the user manually moves files and suggest new custom rules.
- **Mechanism**:
  - Logging manual drag-and-drop movements or duplicate resolutions.
  - Pattern mining (e.g. files with prefix `Invoice_` are always moved to `/Documents/Invoices`).
  - Offering to create a permanent rule in a click.

### Feature 3: File Organization Anomalies
- **Goal**: Spot files that are incorrectly sorted or placed in wrong directories.
- **Mechanism**:
  - Analyzing directory structures using standard TF-IDF or k-Means clustering on file names/extensions.
  - Warning users about out-of-place files (e.g. a `.png` file inside a `.zip` archive or a music file inside a documents directory).

### Feature 4: Smart Space Reclaimer
- **Goal**: Identify heavy or obsolete clusters of files.
- **Mechanism**:
  - Scanning temp directories, build folders (`/build`, `/node_modules`, `/.derivedData`), and application caches.
  - Visualizing the space that can be reclaimed with one-click cleanup recipes.
