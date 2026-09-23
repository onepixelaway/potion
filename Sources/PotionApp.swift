import SwiftUI

@main
struct PotionApp: App {
    @StateObject private var store = ThemeStore()
    @StateObject private var flow = AppFlow()
    init() { FontCatalog.register() }

    var body: some Scene {
        WindowGroup(for: TabRequest.self) { $request in
            RootView(request: request, store: store, flow: flow)
        } defaultValue: {
            TabRequest()
        }
        .defaultSize(width: 1280, height: 860)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands { PotionCommands(store: store, flow: flow) }

        Settings {
            SettingsView(store: store, flow: flow)
        }
    }
}

/// Menu commands. Shortcuts avoid Notion's own (⌘E, ⌘N, ⌘⌥1–9 and the like) because menu shortcuts take
/// precedence over the page. Theme shortcuts use ⌃⌘, which Notion leaves alone.
private struct PotionCommands: Commands {
    @ObservedObject var store: ThemeStore
    @ObservedObject var flow: AppFlow
    @FocusedObject private var workspace: Workspace?
    @FocusedObject private var appearance: AppearanceState?
    @Environment(\.openWindow) private var openWindow

    private var inWorkspace: Bool { !flow.isOnboarding }

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Potion") {
                NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(
                    string: "An independent Mac app for Notion. Not affiliated with Notion.\nFonts from Google Fonts under the SIL Open Font License.",
                    attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor])])
            }
        }
        CommandGroup(after: .appSettings) {
            Button("Sign Out of Notion…") { flow.requestSignOut() }
                .disabled(!inWorkspace)
        }
        CommandGroup(replacing: .newItem) {
            Button("New Tab") { Tabs.open(nil, from: NSApp.keyWindow, using: openWindow) }
                .keyboardShortcut("t")
                .disabled(!inWorkspace)
            Button("New Window") { Tabs.openWindow(using: openWindow) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!inWorkspace)
        }
        CommandGroup(before: .toolbar) {
            Button("Toggle Notion Sidebar") { workspace?.toggleSidebar() }
                .keyboardShortcut("\\")
                .disabled(!inWorkspace || workspace == nil)
            Button(appearance?.isShown == true ? "Hide Appearance" : "Show Appearance") {
                withAnimation(.smooth) { appearance?.isShown.toggle() }
            }
            .keyboardShortcut("i", modifiers: [.command, .control])
            .disabled(!inWorkspace || appearance == nil)
            Divider()
            Button("Reload Page") { workspace?.reload() }
                .keyboardShortcut("r")
                .disabled(workspace == nil)
            Button("Back") { workspace?.goBack() }
                .keyboardShortcut("[")
                .disabled(workspace?.canGoBack != true)
            Button("Forward") { workspace?.goForward() }
                .keyboardShortcut("]")
                .disabled(workspace?.canGoForward != true)
            Button("Open in Browser") { workspace?.openInBrowser() }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(workspace?.canOpenInBrowser != true)
            Divider()
        }
        CommandMenu("Theme") {
            ForEach(Array(([PotionTheme.original] + store.all).enumerated()), id: \.element.id) { index, theme in
                let toggle = Toggle(theme.name, isOn: Binding(get: { store.activeID == theme.id }, set: { if $0 { store.activate(theme.id) } }))
                if index < 9 { toggle.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .control]) } else { toggle }
            }
            Divider()
            Button("Customize Theme…") { appearance?.customize(store.selected) }
                .disabled(!inWorkspace || appearance == nil || !store.enabled)
            Button("New Theme…") { appearance?.newTheme(from: store.selected) }
                .disabled(!inWorkspace || appearance == nil)
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var store: ThemeStore
    @ObservedObject var flow: AppFlow

    var body: some View {
        Form {
            Section("Notion Account") {
                LabeledContent("Status") {
                    Label(flow.isOnboarding ? "Not signed in" : "Signed in",
                          systemImage: flow.isOnboarding ? "person.crop.circle.badge.questionmark" : "checkmark.circle.fill")
                        .foregroundStyle(flow.isOnboarding ? .secondary : Color.green)
                }
                LabeledContent("Sign Out") {
                    Button("Sign Out…") { flow.requestSignOut() }
                        .disabled(flow.isOnboarding)
                }
            }
            Section {
                Picker("Theme", selection: Binding(get: { store.activeID }, set: { store.activate($0) })) {
                    ForEach([PotionTheme.original] + store.all) { theme in Text(theme.name).tag(theme.id) }
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Themes change how Notion looks in Potion on this Mac. Your pages and account aren’t changed.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize()
    }
}
