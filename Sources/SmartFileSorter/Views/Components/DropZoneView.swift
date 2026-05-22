import SwiftUI

public struct DropZoneView: View {
    @Binding var folderPath: String
    let isSorting: Bool
    
    @State private var isDragTargeted = false
    
    public init(folderPath: Binding<String>, isSorting: Bool) {
        self._folderPath = folderPath
        self.isSorting = isSorting
    }
    
    private var formattedPath: String {
        guard !folderPath.isEmpty else { return "" }
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        var display = folderPath.hasPrefix(homeDir)
            ? "~" + folderPath.dropFirst(homeDir.count)
            : folderPath
        let parts = display.components(separatedBy: "/").filter { !$0.isEmpty }
        if parts.count > 3 {
            // Show ~/…/parent/folder
            let last2 = parts.suffix(2).joined(separator: "/")
            display = display.hasPrefix("~") ? "~/…/\(last2)" : "…/\(last2)"
        }
        return display
    }
    
    public var body: some View {
        Button(action: selectFolder) {
            HStack(spacing: 12) {
                // Icon
                if folderPath.isEmpty {
                    Image(systemName: "folder")
                        .font(.system(size: 24))
                        .foregroundColor(isDragTargeted ? DT.Color.accentStrong : DT.Color.textSecondary)
                } else {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundColor(DT.Color.success)
                }
                
                // Texts
                VStack(alignment: .leading, spacing: 2) {
                    if folderPath.isEmpty {
                        Text("Перетягніть папку сюди")
                            .font(DT.Font.bodyWeight(13, weight: .semibold))
                            .foregroundColor(DT.Color.textPrimary)
                        Text("або натисніть, щоб обрати")
                            .font(DT.Font.body(11))
                            .foregroundColor(DT.Color.textSecondary)
                    } else {
                        Text("Обрана папка")
                            .font(DT.Font.bodyWeight(11, weight: .semibold))
                            .foregroundColor(DT.Color.textSecondary)
                        Text(formattedPath)
                            .font(DT.Font.geistMono(13))
                            .foregroundColor(DT.Color.textPrimary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Keyboard hint
                if folderPath.isEmpty {
                    ShortcutHint("⌘O")
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDragTargeted ? DT.Color.accentSoft : DT.Color.glass)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isDragTargeted ? DT.Color.accent : (folderPath.isEmpty ? DT.Color.borderDefault : DT.Color.borderSubtle),
                        style: StrokeStyle(lineWidth: 1, dash: folderPath.isEmpty && !isDragTargeted ? [4, 4] : [])
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSorting)
        .keyboardShortcut("o", modifiers: .command)
        .dropDestination(for: URL.self) { urls, location in
            guard !isSorting else { return false }
            if let url = urls.first, url.hasDirectoryPath {
                folderPath = url.path
                return true
            }
            return false
        } isTargeted: { targeted in
            withAnimation(DT.Animation.springFast) {
                isDragTargeted = targeted
            }
        }
    }
    
    private func selectFolder() {
        guard !isSorting else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.folderPath = url.path
            }
        }
    }
}
