import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TemplatesView: View {
    @State private var showingCollisionAlert = false
    @State private var pendingImportedRule: Rule? = nil
    @State private var errorMessage: String? = nil
    @State private var showSuccessMessage = false
    @State private var successText = ""
    
    @State private var activeSection: String = "myRules"
    @State private var rules: [Rule] = []
    
    // Попередньо налаштовані шаблони
    let templates: [RuleTemplate] = [
        RuleTemplate(
            name: "Downloads cleanup",
            ukName: "Очищення завантажень",
            description: "Automatically sorts files in Downloads by file category (images, videos, documents, archives).",
            ukDescription: "Автоматично сортує файли в Завантаженнях за категоріями (зображення, відео, документи, архіви).",
            rules: [
                Rule(
                    name: "Downloads: Sort Images",
                    enabled: true,
                    conditions: [RuleCondition(type: .kindIs, value: "image")],
                    actions: [RuleAction(type: .moveTo, value: "~/Downloads/Images")]
                ),
                Rule(
                    name: "Downloads: Sort Videos",
                    enabled: true,
                    conditions: [RuleCondition(type: .kindIs, value: "video")],
                    actions: [RuleAction(type: .moveTo, value: "~/Downloads/Videos")]
                ),
                Rule(
                    name: "Downloads: Sort Documents",
                    enabled: true,
                    conditions: [RuleCondition(type: .kindIs, value: "doc")],
                    actions: [RuleAction(type: .moveTo, value: "~/Downloads/Documents")]
                ),
                Rule(
                    name: "Downloads: Sort Archives",
                    enabled: true,
                    conditions: [RuleCondition(type: .kindIs, value: "archive")],
                    actions: [RuleAction(type: .moveTo, value: "~/Downloads/Archives")]
                )
            ]
        ),
        RuleTemplate(
            name: "Photographer workflow",
            ukName: "Процес фотографа",
            description: "Organizes images under ~/Pictures grouped by Camera Model and Date Taken (EXIF).",
            ukDescription: "Організовує фотографії в ~/Pictures за моделлю камери та датою зйомки (EXIF).",
            rules: [
                Rule(
                    name: "Photographer: Organize by Camera & Date",
                    enabled: true,
                    conditions: [RuleCondition(type: .kindIs, value: "image")],
                    actions: [RuleAction(type: .moveTo, value: "~/Pictures/Organized/%camera%/%YYYY%-%MM%")]
                )
            ]
        ),
        RuleTemplate(
            name: "Designer files",
            ukName: "Файли дизайнера",
            description: "Groups graphic source assets (.psd, .ai, .fig) into a single design folder.",
            ukDescription: "Групує вихідні графічні файли (.psd, .ai, .fig) в окрему папку дизайну.",
            rules: [
                Rule(
                    name: "Designer: Sort Assets",
                    enabled: true,
                    conditions: [
                        RuleCondition(logicalOperator: .or, subconditions: [
                            RuleCondition(type: .extensionIs, value: "psd"),
                            RuleCondition(type: .extensionIs, value: "ai"),
                            RuleCondition(type: .extensionIs, value: "fig")
                        ])
                    ],
                    actions: [RuleAction(type: .moveTo, value: "~/Documents/Design")]
                )
            ]
        ),
        RuleTemplate(
            name: "Student documents",
            ukName: "Студентські документи",
            description: "Sorts PDFs that match school or assignment patterns into Academic Documents.",
            ukDescription: "Сортує PDF-файли з навчальними роботами до академічних документів (заготовка для AI v2.0).",
            rules: [
                Rule(
                    name: "Student: Academic PDFs",
                    enabled: true,
                    conditions: [
                        RuleCondition(logicalOperator: .and, subconditions: [
                            RuleCondition(type: .extensionIs, value: "pdf"),
                            RuleCondition(type: .nameMatches, value: "assignment")
                        ])
                    ],
                    actions: [RuleAction(type: .moveTo, value: "~/Documents/Studies")]
                )
            ]
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Заголовок
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("automationTemplates", comment: "Automation Templates"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(DT.Color.textPrimary)
                    Text(NSLocalizedString("templatesSubtitle", comment: "Ready-to-use rule configurations for standard workflows."))
                        .font(.subheadline)
                        .foregroundColor(DT.Color.textSecondary)
                }
                
                Divider()
                
                let locale = Locale.current.language.languageCode?.identifier ?? "en"
                let myRulesLabel = (locale == "uk") ? "Мої правила" : "My Rules"
                let templatesLabel = (locale == "uk") ? "Шаблони правил" : "Templates"
                
                SlidingSegment(
                    selection: $activeSection,
                    options: [
                        (value: "myRules", label: myRulesLabel, icon: Image(systemName: "list.bullet.rectangle.portrait")),
                        (value: "templates", label: templatesLabel, icon: Image(systemName: "square.grid.3x3"))
                    ]
                )
                .frame(maxWidth: 320)
                .padding(.bottom, 8)
                
                if showSuccessMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DT.Color.success)
                        Text(successText)
                            .foregroundColor(DT.Color.success)
                    }
                    .padding()
                    .background(DT.Color.successSoft)
                    .cornerRadius(DT.Radius.md)
                    .transition(.opacity)
                }
                
                if let err = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DT.Color.danger)
                        Text(err)
                            .foregroundColor(DT.Color.danger)
                    }
                    .padding()
                    .background(DT.Color.danger.opacity(0.1))
                    .cornerRadius(DT.Radius.md)
                }
                
                if activeSection == "myRules" {
                    // Вкладка "Мої правила"
                    if rules.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .font(.system(size: 48))
                                .foregroundColor(DT.Color.textSecondary)
                            Text(locale == "uk" ? "Немає створених правил" : "No rules created")
                                .font(.headline)
                                .foregroundColor(DT.Color.textPrimary)
                            Text(locale == "uk" ? "Створіть авто-правило в розділі очищення або додайте з шаблонів." : "Create an auto-rule in the Cleanup section or add one from templates.")
                                .font(.subheadline)
                                .foregroundColor(DT.Color.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .liquidGlass(radius: DT.Radius.lg)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(rules) { rule in
                                RuleRow(rule: rule, locale: locale, onToggle: { isEnabled in
                                    toggleRule(rule, enabled: isEnabled)
                                }, onDelete: {
                                    deleteRule(rule)
                                })
                            }
                        }
                    }
                } else {
                    // Вкладка "Шаблони правил"
                    VStack(alignment: .leading, spacing: 24) {
                        Text(NSLocalizedString("prebuiltTemplates", comment: "Pre-built Rule Packs"))
                            .font(.headline)
                            .foregroundColor(DT.Color.textPrimary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340))], spacing: 16) {
                            ForEach(templates) { template in
                                TemplateCard(template: template) {
                                    importTemplateRules(template.rules)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Експорт та імпорт власних правил
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("ruleSharing", comment: "Import & Export Rules"))
                                .font(.headline)
                                .foregroundColor(DT.Color.textPrimary)
                            
                            HStack(spacing: 16) {
                                Button(action: selectAndImportFile) {
                                    Label(NSLocalizedString("importRuleBtn", comment: "Import Sorter Rule (.sorterrule)..."), systemImage: "square.and.arrow.down")
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(DT.Color.accent)
                                
                                Button(action: exportAllActiveRules) {
                                    Label(NSLocalizedString("exportRulesBtn", comment: "Export All Active Rules..."), systemImage: "square.and.arrow.up")
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            loadRules()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ImportSorterRule"))) { notification in
            if let url = notification.object as? URL {
                importRuleFromFile(url: url)
            }
        }
        .sheet(isPresented: $showingCollisionAlert) {
            if let rule = pendingImportedRule {
                CollisionResolutionSheet(
                    rule: rule,
                    onOverwrite: {
                        overwriteRule(rule)
                        showingCollisionAlert = false
                    },
                    onSaveAsCopy: {
                        saveRuleAsCopy(rule)
                        showingCollisionAlert = false
                    },
                    onCancel: {
                        pendingImportedRule = nil
                        showingCollisionAlert = false
                    }
                )
            }
        }
    }
    
    // Завантаження правил з RuleEngine
    private func loadRules() {
        RuleEngine.shared.loadRules()
        rules = RuleEngine.shared.rules
    }
    
    // Перемикання стану правила
    private func toggleRule(_ rule: Rule, enabled: Bool) {
        RuleEngine.shared.loadRules()
        if let idx = RuleEngine.shared.rules.firstIndex(where: { $0.id == rule.id }) {
            RuleEngine.shared.rules[idx].enabled = enabled
            RuleEngine.shared.saveRules()
            loadRules()
        }
    }
    
    // Видалення правила
    private func deleteRule(_ rule: Rule) {
        RuleEngine.shared.loadRules()
        RuleEngine.shared.rules.removeAll(where: { $0.id == rule.id })
        RuleEngine.shared.saveRules()
        loadRules()
    }
    
    // Імпорт правил шаблону
    private func importTemplateRules(_ rules: [Rule]) {
        RuleEngine.shared.loadRules()
        var addedCount = 0
        var conflictedRules: [Rule] = []
        
        for rule in rules {
            if RuleEngine.shared.rules.contains(where: { $0.name == rule.name }) {
                conflictedRules.append(rule)
            } else {
                RuleEngine.shared.rules.append(rule)
                addedCount += 1
            }
        }
        
        if addedCount > 0 {
            RuleEngine.shared.saveRules()
            loadRules()
            triggerSuccess(String(format: NSLocalizedString("importedCountSuccess", comment: "Successfully imported %d rules."), addedCount))
        }
        
        if !conflictedRules.isEmpty {
            pendingImportedRule = conflictedRules.first
            showingCollisionAlert = true
        }
    }
    
    // Імпорт правила з файлу URL
    private func importRuleFromFile(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let rule = try JSONDecoder().decode(Rule.self, from: data)
            
            RuleEngine.shared.loadRules()
            if RuleEngine.shared.rules.contains(where: { $0.name == rule.name }) {
                pendingImportedRule = rule
                showingCollisionAlert = true
            } else {
                RuleEngine.shared.rules.append(rule)
                RuleEngine.shared.saveRules()
                loadRules()
                triggerSuccess(String(format: NSLocalizedString("importedSingleSuccess", comment: "Imported rule: %@"), rule.name))
            }
        } catch {
            errorMessage = "\(NSLocalizedString("errorImporting", comment: "Failed to parse rule file:")) \(error.localizedDescription)"
        }
    }
    
    private func selectAndImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sorterrule")].compactMap { $0 }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            importRuleFromFile(url: url)
        }
    }
    
    private func exportAllActiveRules() {
        RuleEngine.shared.loadRules()
        guard !RuleEngine.shared.rules.isEmpty else {
            errorMessage = NSLocalizedString("noRulesToExport", comment: "No rules found to export.")
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sorterrule")].compactMap { $0 }
        panel.nameFieldStringValue = "ExportedRules.sorterrule"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                if let firstRule = RuleEngine.shared.rules.first {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(firstRule)
                    try data.write(to: url)
                    triggerSuccess(NSLocalizedString("exportSuccess", comment: "Rules exported successfully!"))
                }
            } catch {
                errorMessage = "\(NSLocalizedString("errorExporting", comment: "Export failed:")) \(error.localizedDescription)"
            }
        }
    }
    
    private func overwriteRule(_ rule: Rule) {
        if let idx = RuleEngine.shared.rules.firstIndex(where: { $0.name == rule.name }) {
            RuleEngine.shared.rules[idx] = rule
            RuleEngine.shared.saveRules()
            loadRules()
            triggerSuccess(NSLocalizedString("overwriteSuccess", comment: "Rule overwritten successfully!"))
        }
    }
    
    private func saveRuleAsCopy(_ rule: Rule) {
        var copy = rule
        copy.id = UUID()
        copy.name = "\(rule.name) \(NSLocalizedString("copySuffix", comment: "Copy"))"
        RuleEngine.shared.rules.append(copy)
        RuleEngine.shared.saveRules()
        loadRules()
        triggerSuccess(String(format: NSLocalizedString("importedSingleSuccess", comment: "Imported rule: %@"), copy.name))
    }
    
    private func triggerSuccess(_ text: String) {
        successText = text
        errorMessage = nil
        withAnimation {
            showSuccessMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation {
                showSuccessMessage = false
            }
        }
    }
}

// Модель для представлення шаблонів у коді
struct RuleTemplate: Identifiable {
    let id = UUID()
    let name: String
    let ukName: String
    let description: String
    let ukDescription: String
    let rules: [Rule]
}

// Карточка представлення шаблону
struct TemplateCard: View {
    let template: RuleTemplate
    let onImport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.badge.gearshape")
                    .font(.title)
                    .foregroundColor(DT.Color.accent)
                
                Spacer()
                
                Button(action: onImport) {
                    Text(NSLocalizedString("addToRulesBtn", comment: "Add to Rules"))
                }
                .buttonStyle(.bordered)
            }
            
            let locale = Locale.current.language.languageCode?.identifier ?? "en"
            let title = (locale == "uk") ? template.ukName : template.name
            let desc = (locale == "uk") ? template.ukDescription : template.description
            
            Text(title)
                .font(.headline)
                .foregroundColor(DT.Color.textPrimary)
            
            Text(desc)
                .font(.subheadline)
                .foregroundColor(DT.Color.textSecondary)
                .lineLimit(3)
        }
        .padding()
        .liquidGlass(radius: DT.Radius.lg)
        .spotlightHover()
    }
}

// Конфліктна шторка
struct CollisionResolutionSheet: View {
    let rule: Rule
    let onOverwrite: () -> Void
    let onSaveAsCopy: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(DT.Color.warning)
            
            Text(NSLocalizedString("ruleConflictTitle", comment: "Rule Conflict Detected"))
                .font(.title2)
                .bold()
                .foregroundColor(DT.Color.textPrimary)
            
            Text(String(format: NSLocalizedString("ruleConflictDesc", comment: "A rule with the name '%@' already exists. How would you like to resolve this?"), rule.name))
                .multilineTextAlignment(.center)
                .foregroundColor(DT.Color.textSecondary)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                Button(action: onOverwrite) {
                    Text(NSLocalizedString("overwriteBtn", comment: "Replace Existing Rule"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DT.Color.danger)
                
                Button(action: onSaveAsCopy) {
                    Text(NSLocalizedString("saveAsCopyBtn", comment: "Keep Both (Import as Copy)"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: onCancel) {
                    Text(NSLocalizedString("cancelBtn", comment: "Cancel Import"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding()
        }
        .padding(24)
        .frame(width: 380)
    }
}

// Рядок правила у списку
struct RuleRow: View {
    let rule: Rule
    let locale: String
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void
    
    @State private var isEnabled: Bool
    
    init(rule: Rule, locale: String, onToggle: @escaping (Bool) -> Void, onDelete: @escaping () -> Void) {
        self.rule = rule
        self.locale = locale
        self.onToggle = onToggle
        self.onDelete = onDelete
        self._isEnabled = State(initialValue: rule.enabled)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: DT.Color.accent))
                .onChange(of: isEnabled) { newValue in
                    onToggle(newValue)
                }
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(rule.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isEnabled ? DT.Color.textPrimary : DT.Color.textSecondary)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(formatConditions(rule.conditions))
                    Text(formatActions(rule.actions))
                }
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(DT.Color.textSecondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(DT.Color.danger)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(14)
        .liquidGlass(radius: DT.Radius.md)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    private func formatConditions(_ conditions: [RuleCondition]) -> String {
        let prefix = locale == "uk" ? "Умови: " : "Conditions: "
        if conditions.isEmpty {
            return prefix + (locale == "uk" ? "немає" : "none")
        }
        let descList = conditions.map { formatCondition($0) }
        return prefix + descList.joined(separator: " та ")
    }
    
    private func formatCondition(_ cond: RuleCondition) -> String {
        if let op = cond.logicalOperator, let subs = cond.subconditions {
            let opStr = op == .and ? (locale == "uk" ? " ТА " : " AND ") : (locale == "uk" ? " АБО " : " OR ")
            return "(" + subs.map { formatCondition($0) }.joined(separator: opStr) + ")"
        }
        guard let type = cond.type, let val = cond.value else { return "" }
        switch type {
        case .nameMatches:
            return locale == "uk" ? "ім'я містить \"\(val)\"" : "name contains \"\(val)\""
        case .extensionIs:
            return locale == "uk" ? "розширення .\(val)" : "extension .\(val)"
        case .kindIs:
            return locale == "uk" ? "тип \(val)" : "kind is \(val)"
        case .sizeGreaterThan:
            let size = Int64(val) ?? 0
            return locale == "uk" ? "розмір > \(formatBytes(size))" : "size > \(formatBytes(size))"
        case .sizeLessThan:
            let size = Int64(val) ?? 0
            return locale == "uk" ? "розмір < \(formatBytes(size))" : "size < \(formatBytes(size))"
        case .sizeEquals:
            let size = Int64(val) ?? 0
            return locale == "uk" ? "розмір = \(formatBytes(size))" : "size = \(formatBytes(size))"
        case .dateAddedWithinDays:
            return locale == "uk" ? "додано протягом \(val) дн." : "added within \(val) days"
        case .dateModifiedWithinDays:
            return locale == "uk" ? "змінено протягом \(val) дн." : "modified within \(val) days"
        case .sourceURLMatches:
            return locale == "uk" ? "URL джерела містить \"\(val)\"" : "source URL contains \"\(val)\""
        case .filenameMatchesRegex:
            return locale == "uk" ? "ім'я відповідає regex \"\(val)\"" : "filename matches regex \"\(val)\""
        case .lastOpenedWithinDays:
            return locale == "uk" ? "відкрито протягом \(val) дн." : "last opened within \(val) days"
        case .hasTag:
            return locale == "uk" ? "має тег \"\(val)\"" : "has tag \"\(val)\""
        case .doesNotHaveTag:
            return locale == "uk" ? "не має тегу \"\(val)\"" : "does not have tag \"\(val)\""
        case .parentFolderIs:
            return locale == "uk" ? "батьківська папка є \"\(val)\"" : "parent folder is \"\(val)\""
        case .ocrTextContains:
            return locale == "uk" ? "текст OCR містить \"\(val)\"" : "OCR text contains \"\(val)\""
        }
    }
    
    private func formatActions(_ actions: [RuleAction]) -> String {
        let prefix = locale == "uk" ? "Дії: " : "Actions: "
        if actions.isEmpty {
            return prefix + (locale == "uk" ? "немає" : "none")
        }
        let descList = actions.map { formatAction($0) }
        return prefix + descList.joined(separator: ", ")
    }
    
    private func formatAction(_ act: RuleAction) -> String {
        switch act.type {
        case .moveTo:
            return locale == "uk" ? "перенести в \(act.value)" : "move to \(act.value)"
        case .copyTo:
            return locale == "uk" ? "скопіювати в \(act.value)" : "copy to \(act.value)"
        case .rename:
            return locale == "uk" ? "перейменувати на \(act.value)" : "rename to \(act.value)"
        case .addTag:
            return locale == "uk" ? "додати тег \"\(act.value)\"" : "add tag \"\(act.value)\""
        case .removeTag:
            return locale == "uk" ? "видалити тег \"\(act.value)\"" : "remove tag \"\(act.value)\""
        case .archiveToZIP:
            return locale == "uk" ? "архівувати в ZIP" : "archive to ZIP"
        case .openWith:
            return locale == "uk" ? "відкрити за допомогою \(act.value)" : "open with \(act.value)"
        case .moveToTrash:
            return locale == "uk" ? "перенести в Смітник" : "move to Trash"
        case .runAppleScript:
            return locale == "uk" ? "запустити AppleScript" : "run AppleScript"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
