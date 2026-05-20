import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var viewModel: WatcherViewModel
    @ObservedObject var profileManager = ProfileManager.shared
    
    public init(viewModel: WatcherViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Розумний сортувальник")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    // Відкриваємо головне вікно додатку
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows {
                        if window.title == "smart-file-sorter" || window.className.contains("NSWindow") {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                }) {
                    Image(systemName: "macwindow")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 5)
            
            Divider()
            
            // Вибір профілю
            HStack {
                Text("Профіль:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
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
            
            Divider()
            
            // Toggle призупинення
            HStack {
                Label(
                    viewModel.isPaused ? "Моніторинг зупинено" : "Моніторинг активний",
                    systemImage: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill"
                )
                .foregroundColor(viewModel.isPaused ? .orange : .green)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { !self.viewModel.isPaused },
                    set: { _ in self.viewModel.togglePause() }
                ))
                .toggleStyle(.switch)
            }
            
            Divider()
            
            Text("Папки під моніторингом (\(viewModel.watchedFolders.count)/5):")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if viewModel.watchedFolders.isEmpty {
                Text("Жодної папки не додано")
                    .font(.callout)
                    .italic()
                    .foregroundColor(.gray)
                    .padding(.vertical, 5)
            } else {
                ForEach(viewModel.watchedFolders, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.callout)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.removeFolder(path: path)
                        }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
            
            Button(action: {
                NSApp.terminate(nil)
            }) {
                Label("Вийти з програми", systemImage: "power")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 260)
    }
}
