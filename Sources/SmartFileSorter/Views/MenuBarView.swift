import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var viewModel: WatcherViewModel
    
    public init(viewModel: WatcherViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Розумний сортувальник")
                    .font(.headline)
                    .foregroundColor(DT.Color.textPrimary)
                
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
                        .foregroundColor(DT.Color.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 5)
            
            Divider()
            
            // Toggle призупинення
            HStack {
                Label(
                    viewModel.isPaused ? "Моніторинг зупинено" : "Моніторинг активний",
                    systemImage: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill"
                )
                .foregroundColor(viewModel.isPaused ? DT.Color.warning : DT.Color.success)
                
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
                .foregroundColor(DT.Color.textSecondary)
            
            if viewModel.watchedFolders.isEmpty {
                Text("Жодної папки не додано")
                    .font(.callout)
                    .italic()
                    .foregroundColor(DT.Color.textTertiary)
                    .padding(.vertical, 5)
            } else {
                ForEach(viewModel.watchedFolders, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(DT.Color.accent)
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.callout)
                            .lineLimit(1)
                            .foregroundColor(DT.Color.textPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.removeFolder(path: path)
                        }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(DT.Color.danger)
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
                    .foregroundColor(DT.Color.danger)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 260)
        .liquidGlass(radius: DT.Radius.md)
    }
}
