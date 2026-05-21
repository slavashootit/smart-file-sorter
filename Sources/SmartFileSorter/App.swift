import SwiftUI
import Sparkle

@main
struct SmartFileSorterApp: App {
    @StateObject private var watcherModel = WatcherViewModel()
    
    // Ініціалізуємо контролер Sparkle 2 для автоматичного оновлення
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    
    init() {
        _ = ProfileManager.shared
        _ = ScheduleManager.shared
        
        DispatchQueue.main.async {
            NSApp.servicesProvider = SorterServicesProvider()
            NSUpdateDynamicServices()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                DT.Color.appBg.ignoresSafeArea()
                MeshBackground()
                
                MainView()
            }
            .preferredColorScheme(.dark)
            .frame(minWidth: 960, idealWidth: 1050, minHeight: 620, idealHeight: 720)
            .onOpenURL { url in
                if url.pathExtension == "sorterrule" {
                    NotificationCenter.default.post(name: NSNotification.Name("ImportSorterRule"), object: url)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        
        MenuBarExtra("Smart File Sorter", systemImage: "folder.badge.gearshape") {
            MenuBarView(viewModel: watcherModel)
            
            Divider()
            
            Button("Перевірити оновлення...") {
                updaterController.checkForUpdates(nil)
            }
            
            Divider()
        }
    }
}
