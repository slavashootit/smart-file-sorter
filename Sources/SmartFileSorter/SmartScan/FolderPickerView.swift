import SwiftUI
import AppKit

struct FolderPickerView: View {
    @ObservedObject var coordinator: SmartScanCoordinator
    @Binding var showFolderPicker: Bool
    @Binding var selectedTab: String
    
    @ObservedObject var favoriteManager = FavoriteFoldersManager.shared
    @State private var selectedURL: URL? = nil
    
    // Alert state for saving new folder to favorites
    @State private var showingSaveAlert = false
    @State private var pendingPathToSave = ""
    
    var body: some View {
        ZStack {
            // Dark glass backdrop to block interactions with background
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Tapping backdrop doesn't dismiss to force selection
                }
            
            // Centered Picker Card
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text("Де шукати?")
                        .font(DT.titleFont)
                        .foregroundColor(DT.Color.textPrimary)
                    
                    Text("Оберіть папку або диск для сканування")
                        .font(DT.bodyFont)
                        .foregroundColor(DT.Color.textSecondary)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                
                Divider()
                    .background(DT.separator)
                
                // Content Scroll Area
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Section: Favorites
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("★ УЛЮБЛЕНІ")
                                    .font(DT.Font.bodyWeight(11, weight: .bold))
                                    .foregroundColor(DT.Color.textSecondary)
                                Spacer()
                            }
                            
                            if favoriteManager.favorites.isEmpty {
                                Text("Немає улюблених папок")
                                    .font(DT.captionFont)
                                    .foregroundColor(DT.Color.textTertiary)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(favoriteManager.favorites, id: \.path) { folder in
                                    FolderRow(
                                        title: folder.displayName,
                                        subtitle: folder.path,
                                        iconName: "star.fill",
                                        isSelected: selectedURL?.path == folder.absolutePath,
                                        action: {
                                            selectedURL = folder.absoluteURL
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Section: Other
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ІНШЕ")
                                .font(DT.Font.bodyWeight(11, weight: .bold))
                                .foregroundColor(DT.Color.textSecondary)
                            
                            FolderRow(
                                title: "Macintosh HD",
                                subtitle: "/",
                                iconName: "harddrive",
                                isSelected: selectedURL?.path == "/",
                                action: {
                                    selectedURL = URL(fileURLWithPath: "/")
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(maxHeight: 240)
                
                Divider()
                    .background(DT.separator)
                
                // Actions Row
                HStack(spacing: 12) {
                    Button(action: selectOtherFolder) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Інша папка...")
                        }
                        .font(DT.bodyFont)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(DT.Color.glass)
                    .cornerRadius(DT.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DT.Radius.md)
                            .stroke(DT.Color.borderDefault, lineWidth: 1)
                    )
                    
                    Spacer()
                    
                    Button(action: startScanning) {
                        HStack {
                            Text("Сканувати")
                            Image(systemName: "arrow.right")
                        }
                        .font(DT.Font.bodyWeight(13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(selectedURL == nil ? DT.Color.glass : DT.Color.accent)
                    .disabled(selectedURL == nil)
                    .cornerRadius(DT.Radius.md)
                    .opacity(selectedURL == nil ? 0.5 : 1.0)
                }
                
                // Footer settings link
                Button(action: {
                    withAnimation {
                        selectedTab = "settings"
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Керувати улюбленими")
                        Image(systemName: "chevron.right")
                    }
                    .font(DT.captionFont)
                    .foregroundColor(DT.Color.textSecondary)
                }
                .buttonStyle(.link)
                .padding(.top, 4)
            }
            .padding(24)
            .frame(width: 440)
            .background(
                RoundedRectangle(cornerRadius: DT.Radius.xl)
                    .fill(DT.Color.elevated.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DT.Radius.xl)
                    .strokeBorder(DT.Color.borderDefault, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 25, x: 0, y: 15)
        }
        .alert("Зберегти в улюблені?", isPresented: $showingSaveAlert) {
            Button("Так") {
                favoriteManager.addFavorite(path: pendingPathToSave)
                selectedURL = URL(fileURLWithPath: pendingPathToSave)
                pendingPathToSave = ""
            }
            Button("Ні", role: .cancel) {
                selectedURL = URL(fileURLWithPath: pendingPathToSave)
                pendingPathToSave = ""
            }
        } message: {
            Text("Додати цю папку до списку швидкого доступу?")
        }
    }
    
    private func selectOtherFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let path = url.path
                // Check if already in favorites
                let home = NSHomeDirectory()
                var normalized = path
                if normalized.hasPrefix(home) {
                    normalized = "~" + normalized.dropFirst(home.count)
                }
                
                let alreadyFavorite = favoriteManager.favorites.contains(where: { $0.path == normalized })
                if alreadyFavorite {
                    selectedURL = url
                } else {
                    pendingPathToSave = path
                    showingSaveAlert = true
                }
            }
        }
    }
    
    private func startScanning() {
        guard let url = selectedURL else { return }
        showFolderPicker = false
        coordinator.startScan(at: url)
    }
}

// Subview for directory row option
struct FolderRow: View {
    let title: String
    let subtitle: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? DT.Color.accentStrong : DT.Color.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: DT.Radius.sm)
                            .fill(isSelected ? DT.Color.accentSoft : DT.Color.glass)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DT.Font.bodyWeight(13, weight: .medium))
                        .foregroundColor(DT.Color.textPrimary)
                    
                    Text(subtitle)
                        .font(DT.captionFont)
                        .foregroundColor(DT.Color.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DT.Color.accentStrong)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.md)
                .fill(isSelected ? DT.Color.accentSoft : (isHovered ? DT.Color.glassHover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DT.Radius.md)
                .stroke(isSelected ? DT.Color.accentStrong.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
