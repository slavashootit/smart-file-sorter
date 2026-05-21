import SwiftUI

struct ExclusionsEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var excludedNames: [String] = []
    @State private var regexPatterns: [String] = []
    @State private var excludedPaths: [String] = []
    
    @State private var selectedTab = 0
    @State private var newName = ""
    @State private var newPattern = ""
    @State private var newPath = ""
    
    init() {
        let current = ConfigManager.shared.exclusions
        _excludedNames = State(initialValue: current.excludedNames)
        _regexPatterns = State(initialValue: current.regexPatterns)
        _excludedPaths = State(initialValue: current.excludedPaths)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Редактор виключень")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Picker("", selection: $selectedTab) {
                Text("Назви").tag(0)
                Text("Шаблони (Regex)").tag(1)
                Text("Шляхи").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            VStack {
                if selectedTab == 0 {
                    // Names list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ігнорувати файли/папки з цими назвами:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        HStack {
                            TextField("Наприклад: node_modules", text: $newName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    addName()
                                }
                            Button("Додати") {
                                addName()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        
                        List {
                            ForEach(excludedNames, id: \.self) { name in
                                HStack {
                                    Text(name)
                                    Spacer()
                                    Button(action: {
                                        excludedNames.removeAll(where: { $0 == name })
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                } else if selectedTab == 1 {
                    // Regex patterns list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ігнорувати назви за регулярними виразами:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        HStack {
                            TextField("Наприклад: ^\\d{4}$ (рік)", text: $newPattern)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    addPattern()
                                }
                            Button("Додати") {
                                addPattern()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        
                        List {
                            ForEach(regexPatterns, id: \.self) { pattern in
                                HStack {
                                    Text(pattern)
                                    Spacer()
                                    Button(action: {
                                        regexPatterns.removeAll(where: { $0 == pattern })
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                } else {
                    // Paths list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ігнорувати файли/папки за цими шляхами:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        HStack {
                            TextField("Наприклад: /System або ~/Downloads/Temp", text: $newPath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    addPath()
                                }
                            Button("Огляд...") {
                                selectFolderPath()
                            }
                            Button("Додати") {
                                addPath()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        
                        List {
                            ForEach(excludedPaths, id: \.self) { path in
                                HStack {
                                    Text(path)
                                    Spacer()
                                    Button(action: {
                                        excludedPaths.removeAll(where: { $0 == path })
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(height: 250)
            
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
                    let updated = ExclusionsConfig(
                        excludedNames: excludedNames,
                        regexPatterns: regexPatterns,
                        excludedPaths: excludedPaths
                    )
                    ConfigManager.shared.updateExclusions(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 420)
    }
    
    private func addName() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !excludedNames.contains(trimmed) {
            excludedNames.append(trimmed)
            newName = ""
        }
    }
    
    private func addPattern() {
        let trimmed = newPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !regexPatterns.contains(trimmed) {
            if (try? NSRegularExpression(pattern: trimmed)) != nil {
                regexPatterns.append(trimmed)
                newPattern = ""
            }
        }
    }
    
    private func addPath() {
        let trimmed = newPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !excludedPaths.contains(trimmed) {
            excludedPaths.append(trimmed)
            newPath = ""
        }
    }
    
    private func selectFolderPath() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let rawPath = url.path
                let homeDir = NSHomeDirectory()
                if rawPath.hasPrefix(homeDir) {
                    newPath = rawPath.replacingOccurrences(of: homeDir, with: "~")
                } else {
                    newPath = rawPath
                }
            }
        }
    }
    
    private func resetToDefaults() {
        excludedNames = [
            "Відео", "Зображення", "Документи", "Аудіо", "Архіви", "Дублікати", "Інші файли",
            ".git", "node_modules", ".Trash", ".trash", "timemachine.backupdb"
        ]
        regexPatterns = [
            "^\\d{4}$",
            ".*\\.backupbundle$",
            ".*\\.backupdb$"
        ]
        excludedPaths = [
            "/System",
            "/Library",
            "/private",
            "/usr",
            "/bin",
            "/sbin",
            "~/Library",
            "~/.Trash"
        ]
    }
}
