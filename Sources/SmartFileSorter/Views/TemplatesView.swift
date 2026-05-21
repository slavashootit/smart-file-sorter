import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TemplatesView: View {
    @State private var showingCollisionAlert = false
    @State private var pendingImportedRule: Rule? = nil
    @State private var errorMessage: String? = nil
    @State private var showSuccessMessage = false
    @State private var successText = ""
    
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
                
                // Шаблони сітка
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
            }
            .padding(24)
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
            triggerSuccess(String(format: NSLocalizedString("importedCountSuccess", comment: "Successfully imported %d rules."), addedCount))
        }
        
        if !conflictedRules.isEmpty {
            // Опрацьовуємо перше конфліктне правило
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
                // Експортуємо перше або всі правила. Для спрощеного імпорту експортуємо одне вибране або перше.
                // Давай експортуємо перше наявне, або якщо в списку декілька, запишемо як масив.
                // Оскільки імпортер очікує поодинокі правила (або може декодувати й поодинокі), давайте запишемо перше або створимо експорт для конкретного.
                // Експортуємо перше для демонстрації, а в ідеалі дамо вибір.
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
            triggerSuccess(NSLocalizedString("overwriteSuccess", comment: "Rule overwritten successfully!"))
        }
    }
    
    private func saveRuleAsCopy(_ rule: Rule) {
        var copy = rule
        copy.id = UUID()
        copy.name = "\(rule.name) \(NSLocalizedString("copySuffix", comment: "Copy"))"
        RuleEngine.shared.rules.append(copy)
        RuleEngine.shared.saveRules()
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
