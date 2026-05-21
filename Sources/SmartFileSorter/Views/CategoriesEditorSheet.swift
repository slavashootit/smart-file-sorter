import SwiftUI

struct CategoriesEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var categories: [String: [String]] = [:]
    @State private var selectedCategory: String = ""
    @State private var newCategoryName = ""
    @State private var newExtension = ""
    @State private var showAddCategoryAlert = false
    
    init() {
        let current = ConfigManager.shared.categories
        _categories = State(initialValue: current)
        if let first = current.keys.sorted().first {
            _selectedCategory = State(initialValue: first)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Редактор категорій")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            HSplitView {
                // Left Column: Categories List
                VStack(spacing: 0) {
                    List(selection: $selectedCategory) {
                        ForEach(categories.keys.sorted(), id: \.self) { cat in
                            Text(cat)
                                .tag(cat)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Button(action: {
                            showAddCategoryAlert = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        
                        Spacer()
                        
                        Button(action: {
                            if !selectedCategory.isEmpty {
                                categories.removeValue(forKey: selectedCategory)
                                selectedCategory = categories.keys.sorted().first ?? ""
                            }
                        }) {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .disabled(selectedCategory.isEmpty)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                }
                .frame(width: 180)
                
                // Right Column: Extensions for selected category
                VStack(alignment: .leading, spacing: 0) {
                    if !selectedCategory.isEmpty {
                        Text("Розширення файлів для '\(selectedCategory)':")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding()
                        
                        HStack {
                            TextField("Наприклад: png або zip", text: $newExtension)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    addExtension()
                                }
                            Button("Додати") {
                                addExtension()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        
                        List {
                            ForEach(categories[selectedCategory] ?? [], id: \.self) { ext in
                                HStack {
                                    Text(".\(ext)")
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Button(action: {
                                        categories[selectedCategory]?.removeAll(where: { $0 == ext })
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        VStack {
                            Spacer()
                            Text("Виберіть або додайте категорію")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 280)
            
            Divider()
            
            // Actions
            HStack {
                Button("Скинути до початкових") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Скасувати") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Зберегти") {
                    ConfigManager.shared.updateCategories(categories)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 420)
        .sheet(isPresented: $showAddCategoryAlert) {
            VStack(spacing: 16) {
                Text("Нова категорія")
                    .font(.headline)
                TextField("Назва категорії", text: $newCategoryName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                    .onSubmit {
                        createCategory()
                    }
                
                HStack {
                    Button("Скасувати") {
                        showAddCategoryAlert = false
                        newCategoryName = ""
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Створити") {
                        createCategory()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(width: 280, height: 150)
        }
    }
    
    private func addExtension() {
        let trimmed = newExtension.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
        if !trimmed.isEmpty, var exts = categories[selectedCategory], !exts.contains(trimmed) {
            exts.append(trimmed)
            categories[selectedCategory] = exts
            newExtension = ""
        }
    }
    
    private func createCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && categories[trimmed] == nil {
            categories[trimmed] = []
            selectedCategory = trimmed
        }
        showAddCategoryAlert = false
        newCategoryName = ""
    }
    
    private func resetToDefaults() {
        categories = [
            "Зображення": ["jpg", "jpeg", "png", "gif", "bmp", "heic", "tiff", "svg", "webp", "raw"],
            "Відео": ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"],
            "Документи": ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "odt", "csv", "pages", "numbers", "key"],
            "Аудіо": ["mp3", "wav", "m4a", "flac", "aac", "ogg", "wma"],
            "Архіви": ["zip", "rar", "7z", "tar", "gz", "dmg", "pkg"]
        ]
        if !categories.keys.contains(selectedCategory) {
            selectedCategory = categories.keys.sorted().first ?? ""
        }
    }
}
