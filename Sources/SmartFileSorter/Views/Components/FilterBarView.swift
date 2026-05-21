import SwiftUI

public struct FilterBarView: View {
    @Binding var sortMode: SortMode
    @Binding var enabledCategories: [String: Bool]
    @Binding var detectDuplicates: Bool
    
    public init(
        sortMode: Binding<SortMode>,
        enabledCategories: Binding<[String: Bool]>,
        detectDuplicates: Binding<Bool>
    ) {
        self._sortMode = sortMode
        self._enabledCategories = enabledCategories
        self._detectDuplicates = detectDuplicates
    }
    
    private var sortedCategories: [String] {
        enabledCategories.keys.sorted()
    }
    
    private var visibleCategories: [String] {
        Array(sortedCategories.prefix(3))
    }
    
    private var hiddenCategories: [String] {
        Array(sortedCategories.dropFirst(3))
    }
    
    private var anyHiddenEnabled: Bool {
        hiddenCategories.contains { enabledCategories[$0] ?? true }
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Zone B1: Sort Mode Picker Menu
            Menu {
                Button(action: {
                    sortMode = .type
                    Haptics.alignment()
                }) {
                    HStack {
                        Text("За типом")
                        if sortMode == .type {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: {
                    sortMode = .date
                    Haptics.alignment()
                }) {
                    HStack {
                        Text("За датою")
                        if sortMode == .date {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: sortMode == .type ? "square.grid.2x2" : "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(DT.Color.accentStrong)
                    Text(sortMode == .type ? "За типом" : "За датою")
                        .font(DT.Font.bodyWeight(13, weight: .semibold))
                        .foregroundColor(DT.Color.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(DT.Color.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DT.Color.glass)
                .cornerRadius(8)
            }
            .menuStyle(.borderlessButton)
            .help("Режим групування файлів")
            
            Divider()
                .frame(height: 16)
                .background(DT.Color.borderSubtle)
            
            // Zone B2: Horizontal Scroll of Category Chips
            HStack(spacing: 8) {
                ForEach(visibleCategories, id: \.self) { cat in
                    let isEnabled = enabledCategories[cat] ?? true
                    Button(action: {
                        enabledCategories[cat] = !isEnabled
                        Haptics.levelChange()
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isEnabled ? DT.Color.accentStrong : DT.Color.textFaint)
                                .frame(width: 6, height: 6)
                            Text(cat)
                                .font(DT.Font.bodyWeight(12, weight: .medium))
                                .foregroundColor(isEnabled ? DT.Color.textPrimary : DT.Color.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isEnabled ? DT.Color.accentSoft : DT.Color.glass)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isEnabled ? DT.Color.accent.opacity(0.4) : DT.Color.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .spotlightHover()
                }
                
                if !hiddenCategories.isEmpty {
                    Menu {
                        ForEach(hiddenCategories, id: \.self) { cat in
                            let isEnabled = enabledCategories[cat] ?? true
                            Button(action: {
                                enabledCategories[cat] = !isEnabled
                                Haptics.levelChange()
                            }) {
                                HStack {
                                    Text(cat)
                                    if isEnabled {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("+\(hiddenCategories.count)")
                                .font(DT.Font.bodyWeight(12, weight: .semibold))
                                .foregroundColor(anyHiddenEnabled ? DT.Color.textPrimary : DT.Color.textSecondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(DT.Color.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(anyHiddenEnabled ? DT.Color.accentSoft : DT.Color.glass)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(anyHiddenEnabled ? DT.Color.accent.opacity(0.4) : DT.Color.borderSubtle, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .spotlightHover()
                }
            }
            
            Spacer()
            
            Divider()
                .frame(height: 16)
                .background(DT.Color.borderSubtle)
            
            // Zone B3: Duplicates Toggle
            Toggle(isOn: $detectDuplicates) {
                Text("Дублікати")
                    .font(DT.Font.bodyWeight(13, weight: .medium))
                    .foregroundColor(DT.Color.textPrimary)
            }
            .toggleStyle(.checkbox)
            .onChange(of: detectDuplicates) { _ in
                Haptics.alignment()
            }
            .help("Виявляти однакові файли під час сортування")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DT.Color.elevated)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(DT.Color.borderDefault, lineWidth: 1)
        )
    }
}
