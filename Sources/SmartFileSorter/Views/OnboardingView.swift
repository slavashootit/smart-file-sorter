import SwiftUI
import AppKit

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var step = 0
    @State private var mostDownloaded = "documents"
    @State private var scanPath = NSHomeDirectory() + "/Downloads"
    
    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) {
                ForEach(0..<4) { idx in
                    Circle()
                        .fill(step == idx ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 24)
            
            Spacer()
            
            switch step {
            case 0:
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    
                    Text("Ласкаво просимо до Smart File Sorter v2.0")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Ваш інтелектуальний помічник на базі ШІ для автоматичного прибирання диска в реальному часі.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 380)
                }
                
            case 1:
                VStack(spacing: 16) {
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    
                    Text("Які файли ви завантажуєте найчастіше?")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Picker("", selection: $mostDownloaded) {
                        Text("Документи та PDF").tag("documents")
                        Text("Зображення та Фото").tag("images")
                        Text("Відео").tag("videos")
                        Text("Архіви (ZIP/RAR)").tag("archives")
                    }
                    .pickerStyle(RadioGroupPickerStyle())
                    .frame(width: 240)
                }
                
            case 2:
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    
                    Text("Дозвіл на доступ до папки")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Sorter буде стежити за вибраною папкою та автоматично впорядковувати її.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 320)
                    
                    HStack {
                        TextField("Папка стеження", text: $scanPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(true)
                        
                        Button("Вибрати...") {
                            selectFolder()
                        }
                    }
                    .frame(width: 320)
                }
                
            case 3:
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    
                    Text("Все готово до роботи!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Ми автоматично створили перше правило на основі ваших уподобань.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 320)
                }
                
            default:
                EmptyView()
            }
            
            Spacer()
            
            HStack {
                if step > 0 {
                    Button("Назад") {
                        withAnimation { step -= 1 }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(step == 3 ? "Розпочати роботу" : "Продовжити") {
                    if step == 3 {
                        createInitialProfile()
                        isCompleted = true
                    } else {
                        withAnimation { step += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 500, height: 420)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            scanPath = url.path
        }
    }
    
    private func createInitialProfile() {
        var conditions: [RuleCondition] = []
        var action = RuleAction(type: .moveTo, value: NSHomeDirectory() + "/Documents")
        
        switch mostDownloaded {
        case "documents":
            conditions = [RuleCondition(type: .extensionIs, value: "pdf")]
            action = RuleAction(type: .moveTo, value: NSHomeDirectory() + "/Documents/PDFs")
        case "images":
            conditions = [RuleCondition(type: .kindIs, value: "image")]
            action = RuleAction(type: .moveTo, value: NSHomeDirectory() + "/Pictures/Sorted")
        case "videos":
            conditions = [RuleCondition(type: .kindIs, value: "video")]
            action = RuleAction(type: .moveTo, value: NSHomeDirectory() + "/Movies")
        case "archives":
            conditions = [RuleCondition(type: .extensionIs, value: "zip")]
            action = RuleAction(type: .moveTo, value: NSHomeDirectory() + "/Downloads/Archives")
        default:
            break
        }
        
        let initialRule = Rule(
            name: "Початкове авто-сортування",
            enabled: true,
            conditions: conditions,
            actions: [action]
        )
        
        let engine = RuleEngine.shared
        engine.rules.append(initialRule)
        engine.saveRules()
    }
}
