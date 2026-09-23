import SwiftUI

@main
struct PotionApp: App {
    @StateObject private var store = ThemeStore()
    @StateObject private var workspace = Workspace()
    init() { FontCatalog.register() }
    var body: some Scene {
        Window("Potion", id: "main") {
            ContentView(store: store, workspace: workspace)
                .frame(minWidth: 1000, minHeight: 720)
                .onAppear {
                    workspace.apply(store.selected, enabled: store.enabled)
                    workspace.showPreview()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onChange(of: store.selected) { _, theme in workspace.apply(theme, enabled: store.enabled) }
                .onChange(of: store.enabled) { _, enabled in workspace.apply(store.selected, enabled: enabled) }
        }
        .defaultSize(width: 1280, height: 870)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Open Notion") { workspace.openNotion() }.keyboardShortcut("o")
                Button("Theme Preview") { workspace.showPreview() }.keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Reload Page") { workspace.reload() }.keyboardShortcut("r")
                Button("Open in Browser") { workspace.openInBrowser() }.keyboardShortcut("b", modifiers: [.command, .shift])
                Divider()
                Toggle("Apply Potion Theme", isOn: $store.enabled)
            }
        }
    }
}
