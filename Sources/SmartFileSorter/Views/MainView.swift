import SwiftUI
import AppKit
import Combine

struct MainView: View {
    @ObservedObject var profileManager = ProfileManager.shared
    @State private var selectedTab: String = "sort"
    @State private var folderPath: String = ""
    @State private var sortMode: SortMode = .type
    @State private var detectDuplicates: Bool = false
    @State private var logs: [String] = []
    @State private var hasHistory: Bool = SorterEngine.shared.checkHistoryExists()
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var showingSmartSelectionAlert = false
    @State private var suggestedPattern: DuplicateSelectionPattern = .none
    @State private var isSorting = false
    @State private var sortingTask: Task<Void, Never>? = nil
    @State private var processedCount = 0
    @State private var totalCount = 0
    @State private var currentItem = ""
    
    @State private var enabledCategories: [String: Bool] = [
        "Зображення": true,
        "Відео": true,
        "Документи": true,
        "Аудіо": true,
        "Архіви": true,
        "Інші файли": true
    ]
    
    @State private var showExclusionsEditor = false
    @State private var showCategoriesEditor = false
    
    var body: some View {
        ZStack {
            NavigationSplitView {
                List(selection: $selectedTab) {
                    Section(header: Text("Активний профіль").padding(.leading, 6)) {
                        Picker("", selection: Binding(
                            get: { self.profileManager.activeProfile },
                            set: { self.profileManager.switchProfile(to: $0) }
                        )) {
                            ForEach(self.profileManager.profiles) { profile in
                                Text(profile.name).tag(profile)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    
                    Section(header: Text("Навігація").padding(.leading, 6)) {
                        NavigationLink(value: "sort") {
                            Label("Сортування", systemImage: "folder.badge.gearshape")
                        }
                        .help("Автоматичне сортування файлів у папці за типом або датою")
                        
                        NavigationLink(value: "diskMap") {
                            Label("Аналізатор диска", systemImage: "chart.pie")
                        }
                        .help("Візуальна карта використання диска — знайдіть найбільші папки")
                        
                        NavigationLink(value: "duplicates") {
                            Label("Дублікати", systemImage: "doc.on.doc")
                        }
                        .help("Пошук і видалення дублікатів файлів за хешем вмісту")
                        
                        NavigationLink(value: "similar") {
                            Label("Схожі фото", systemImage: "photo.on.rectangle.angled")
                        }
                        .help("Знаходить візуально схожі фотографії за допомогою Apple Vision AI")
                        
                        NavigationLink(value: "semantic") {
                            Label("Семантичний пошук", systemImage: "sparkles")
                        }
                        .help("Пошук фотографій за текстовим описом (англ.) — Vision AI розпізнає об'єкти")
                        
                        NavigationLink(value: "cleanup") {
                            Label("Очищення", systemImage: "trash")
                        }
                        .help("Великі файли, старі завантаження, порожні папки та керування Смітником")
                        
                        NavigationLink(value: "templates") {
                            Label(NSLocalizedString("automationTemplates", comment: ""), systemImage: "square.grid.3x3")
                        }
                        .help("Готові шаблони правил автоматичного сортування для швидкого старту")
                        
                        NavigationLink(value: "analytics") {
                            Label("Аналітика", systemImage: "chart.xyaxis.line")
                        }
                        .help("Статистика сортувань, звільненого простору та активності за часом")
                        
                        NavigationLink(value: "settings") {
                            Label("Налаштування", systemImage: "gearshape")
                        }
                        .help("Розклад автосортування, звукові ефекти та системні параметри")
                        
                        NavigationLink(value: "about") {
                            Label("Про програму", systemImage: "info.circle")
                        }
                        .help("Версія додатку, посилання на GitHub та інформація про розробника")
                    }
                }
                .listStyle(.sidebar)
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
            } detail: {
                ZStack {
                    VisualEffectView(material: .windowBackground, blendingMode: .behindWindow)
                    
                    switch selectedTab {
                    case "sort":
                        sortTab
                    case "diskMap":
                        SunburstChartView()
                    case "duplicates":
                        DuplicateReviewView()
                    case "similar":
                        SimilarPhotosView()
                    case "semantic":
                        SemanticSearchView()
                    case "cleanup":
                        CleanupView()
                    case "templates":
                        TemplatesView()
                    case "analytics":
                        AnalyticsHeatmapView()
                    case "settings":
                        settingsTab
                    case "about":
                        aboutTab
                    default:
                        Text("Виберіть вкладку")
                    }
                }
                .navigationTitle(NSLocalizedString("appName", comment: ""))
            }
            
            // Global Flying File Animation Canvas
            AnimationOverlay()
            
            // Onboarding Overlay if not completed
            if !onboardingCompleted {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardingView(isCompleted: $onboardingCompleted)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SmartSelectionSuggestion"))) { note in
            if let pattern = note.object as? DuplicateSelectionPattern {
                suggestedPattern = pattern
                showingSmartSelectionAlert = true
            }
        }
        .sheet(isPresented: $showingSmartSelectionAlert) {
            VStack(spacing: 16) {
                Text("Розумний вибір")
                    .font(.headline)
                Text("Ви часто обираєте варіант '\(suggestedPattern == .older ? "старіший" : "новіший")'. Бажаєте встановити його за замовчуванням для авто-вибору?")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                HStack(spacing: 12) {
                    Button("Встановити") {
                        SmartSelectionLearner.shared.approvePattern(suggestedPattern)
                        showingSmartSelectionAlert = false
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Скасувати") {
                        showingSmartSelectionAlert = false
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(width: 320, height: 180)
        }
        .sheet(isPresented: $showExclusionsEditor) {
            ExclusionsEditorSheet()
        }
        .sheet(isPresented: $showCategoriesEditor, onDismiss: {
            syncCategories()
        }) {
            CategoriesEditorSheet()
        }
        .onAppear {
            syncCategories()
        }
    }
    
    // Вкладка Сортування
    private var sortTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Попередження про конфлікти правил
                let conflicts = RuleEngine.shared.detectConflicts()
                if !conflicts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Виявлено конфлікти у правилах:")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        ForEach(conflicts, id: \.self) { conflict in
                            Text("• \(conflict)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Вибір папки
                VStack(alignment: .leading, spacing: 8) {
                    Text("selectFolder")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Шлях до папки...", text: $folderPath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: selectFolder) {
                            Label("Огляд...", systemImage: "folder.circle")
                        }
                    }
                }
                .disabled(isSorting)
                .padding()
                .background(Color.primary.opacity(0.03))
                .cornerRadius(12)
                
                // Налаштування сортування
                HStack(alignment: .top, spacing: 20) {
                    // Режим сортування
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Режим сортування")
                            .font(.headline)
                        
                        Picker("", selection: $sortMode) {
                            Text("За типом").tag(SortMode.type)
                            Text("За датою").tag(SortMode.date)
                        }
                        .pickerStyle(.radioGroup)
                        
                        Toggle("Виявляти дублікати", isOn: $detectDuplicates)
                            .toggleStyle(.checkbox)
                            .padding(.top, 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Вибір категорій
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Категорії для сортування")
                            .font(.headline)
                        
                        ForEach(Array(enabledCategories.keys.sorted()), id: \.self) { cat in
                            Toggle(cat, isOn: Binding(
                                get: { self.enabledCategories[cat] ?? true },
                                set: { self.enabledCategories[cat] = $0 }
                            ))
                            .toggleStyle(.checkbox)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(isSorting)
                .padding()
                .background(Color.primary.opacity(0.03))
                .cornerRadius(12)
                
                // Кнопки дій або Прогрес сортування
                if isSorting {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Впорядкування файлів...")
                                .font(.headline)
                            Spacer()
                            Text("\(processedCount) з \(totalCount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if !currentItem.isEmpty {
                            Text(currentItem)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        ProgressView(value: Double(processedCount), total: Double(max(1, totalCount)))
                            .progressViewStyle(.linear)
                        
                        Button(action: { sortingTask?.cancel() }) {
                            Label("Скасувати сортування", systemImage: "xmark.circle")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding()
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
                } else {
                    HStack(spacing: 15) {
                        Button(action: { runSorting(dryRun: true) }) {
                            Label("previewSorting", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Button(action: { runSorting(dryRun: false) }) {
                            Label("startSorting", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.large)
                    }
                    
                    if hasHistory {
                        Button(action: undoSorting) {
                            Label("undoSorting", systemImage: "arrow.uturn.backward")
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                
                // Панель логів (неонова консоль)
                if !logs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Журнал операцій")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(logs, id: \.self) { log in
                                    Text(log)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(getLogColor(log))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(10)
                        }
                        .frame(height: 180)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }
    
    // Вкладка Налаштування
    private var settingsTab: some View {
        Form {
            Section(header: Text("Системні налаштування")) {
                Toggle("Автоматичне оновлення через Sparkle 2", isOn: .constant(true))
                Toggle("Використовувати апаратне прискорення Apple Vision", isOn: .constant(true))
                Toggle("Ігнорувати приховані системні файли", isOn: .constant(true))
                Toggle("Звукові ефекти сортування", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "soundEnabled") },
                    set: { UserDefaults.standard.set($0, forKey: "soundEnabled") }
                ))
            }
            
            Section(header: Text("Розклад автоматичного сортування")) {
                Picker("Періодичність", selection: Binding(
                    get: { UserDefaults.standard.string(forKey: "schedule_interval") ?? "daily" },
                    set: {
                        UserDefaults.standard.set($0, forKey: "schedule_interval")
                        ScheduleManager.shared.setupScheduler()
                    }
                )) {
                    Text("Вручну (відключено)").tag("none")
                    Text("Щогодини").tag("hourly")
                    Text("Щодня").tag("daily")
                    Text("Щотижня").tag("weekly")
                }
                .pickerStyle(.inline)
            }
            
            Section(header: Text("Параметри сортування")) {
                Button("Редагувати виключення файлів...") {
                    showExclusionsEditor = true
                }
                Button("Редагувати категорії файлів...") {
                    showCategoriesEditor = true
                }
            }
        }
        .padding()
    }
    
    // Вкладка Про програму
    private var aboutTab: some View {
        VStack(spacing: 15) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 72))
                .foregroundColor(.blue)
            
            Text("smart-file-sorter")
                .font(.title)
                .bold()
            
            Text("Версія 2.0.0-alpha (Swift Native)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Преміальний настільний додаток для швидкого та безпечного впорядкування хаосу у ваших папках.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Link("Репозиторій на GitHub", destination: URL(string: "https://github.com/slavashootit/smart-file-sorter")!)
                .buttonStyle(.link)
        }
        .padding()
    }
    
    // Вибір папки діалогом macOS
    private var openPanel: NSOpenPanel {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        return panel
    }
    
    private func selectFolder() {
        let panel = openPanel
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.folderPath = url.path
            }
        }
    }
    
    // Запуск сортування
    private func runSorting(dryRun: Bool) {
        guard !folderPath.isEmpty else { return }
        
        isSorting = true
        processedCount = 0
        totalCount = 0
        currentItem = ""
        logs.removeAll()
        
        sortingTask = Task { @MainActor in
            let stream = SorterEngine.shared.sortFiles(
                folderPath: folderPath,
                sortMode: sortMode,
                categories: enabledCategories,
                dryRun: dryRun,
                detectDuplicates: detectDuplicates
            )
            
            for await progress in stream {
                if Task.isCancelled { break }
                self.processedCount = progress.processedCount
                self.totalCount = progress.totalCount
                self.currentItem = progress.currentItem
                if let entry = progress.logEntry {
                    self.logs.append(entry)
                }
                if progress.isFinished {
                    if let finals = progress.finalLogs {
                        self.logs.append(contentsOf: finals)
                    }
                }
            }
            
            isSorting = false
            hasHistory = SorterEngine.shared.checkHistoryExists()
            sortingTask = nil
        }
    }
    
    // Скасування сортування
    private func undoSorting() {
        logs = SorterEngine.shared.undoSorting()
        hasHistory = SorterEngine.shared.checkHistoryExists()
    }
    
    // Підсвітка логів
    private func getLogColor(_ log: String) -> Color {
        if log.contains("[УСПІШНО]") {
            return .green
        } else if log.contains("[ПЛАНУЄТЬСЯ]") {
            return .blue
        } else if log.contains("[ДУБЛІКАТ]") {
            return .cyan
        } else if log.contains("[ПОМИЛКА]") {
            return .red
        } else if log.contains("[ПРОПУЩЕНО]") {
            return .gray
        } else if log.contains("[ВІДНОВЛЕНО]") {
            return .orange
        }
        return .white
    }
    
    private func syncCategories() {
        var newDict: [String: Bool] = [:]
        for cat in ConfigManager.shared.categories.keys {
            newDict[cat] = enabledCategories[cat] ?? true
        }
        newDict["Інші файли"] = enabledCategories["Інші файли"] ?? true
        enabledCategories = newDict
    }
}
