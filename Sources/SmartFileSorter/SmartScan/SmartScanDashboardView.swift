import SwiftUI

enum SmartScanState {
    case scanning
    case results
    case confirmingFixAll
}

struct SmartScanDashboardView: View {
    @ObservedObject var coordinator: SmartScanCoordinator
    @State private var viewState: SmartScanState = .scanning
    @State private var showToast = false
    @State private var toastMessage = ""

    // Папка що сканується — передається при відкритті
    let targetURL: URL?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch viewState {
                case .scanning:
                    ScanProgressView(progress: coordinator.progress)
                        .transition(.opacity)

                case .results:
                    if let results = coordinator.results {
                        ScanResultsView(
                            results: Binding(
                                get: { coordinator.results ?? results },
                                set: { coordinator.results = $0 }
                            ),
                            onFixAll: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    viewState = .confirmingFixAll
                                }
                            }
                        )
                        .transition(.opacity)
                    }

                case .confirmingFixAll:
                    FixAllInlineView(
                        issues: Binding(
                            get: { coordinator.results?.issues ?? [] },
                            set: { newIssues in
                                if let r = coordinator.results {
                                    coordinator.results = ScanResults(
                                        issues: newIssues,
                                        scannedPath: r.scannedPath,
                                        scannedAt: r.scannedAt
                                    )
                                }
                            }
                        ),
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewState = .results
                            }
                        },
                        onConfirm: { selected in
                            Task { await performFixAll(issues: selected) }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewState)

            // Toast
            if showToast {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            if coordinator.results != nil {
                viewState = .results
            } else {
                viewState = .scanning
            }
            if let url = targetURL {
                coordinator.startScan(at: url)
            }
        }
        .onChangeCompat(of: coordinator.results) { results in
            guard results != nil else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                viewState = .results
            }
        }
    }

    // ── Fix All action ──────────────────────────────────────
    @MainActor
    private func performFixAll(issues: [ScanIssue]) async {
        let urls = issues.flatMap(\.urls)
        guard !urls.isEmpty else { return }

        withAnimation { viewState = .results }

        do {
            // moveToTrash — НІКОЛИ removeItem
            try await SorterEngine.shared.moveToTrash(urls)
            let sizeStr = ByteCountFormatter.string(
                fromByteCount: issues.reduce(0) { $0 + $1.bytes },
                countStyle: .file
            )
            showToastMessage("\(urls.count) файлів (\(sizeStr)) у Кошику")

            // Оновлюємо results — прибираємо виконані issues
            let doneIDs = Set(issues.map(\.id))
            if let r = coordinator.results {
                coordinator.results = ScanResults(
                    issues: r.issues.filter { !doneIDs.contains($0.id) },
                    scannedPath: r.scannedPath,
                    scannedAt: r.scannedAt
                )
            }
        } catch {
            showToastMessage("Помилка: \(error.localizedDescription)")
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.3)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut(duration: 0.3)) { showToast = false }
        }
    }
}

struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(DT.captionFont)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
