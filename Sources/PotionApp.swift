import SwiftUI

@main
struct PotionApp: App {
    @StateObject private var store = ThemeStore()
    @StateObject private var flow = AppFlow()
    init() {
        FontCatalog.register()
        // Tabs live in Potion's header, as in Notion's app, rather than in the system tab bar.
        NSWindow.allowsAutomaticWindowTabbing = false
        // Potion restores its own tabs, so system window restoration is off and a stale saved window can't stop the
        // window from opening at launch.
        UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true])
    }

    var body: some Scene {
        WindowGroup(id: "workspace") {
            RootView(store: store, flow: flow)
        }
        .defaultSize(width: 1280, height: 860)
        .restorationBehavior(.disabled)
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
    @FocusedObject private var tabs: BrowserTabs?
    @FocusedValue(\.workspace) private var workspace
    @FocusedObject private var appearance: AppearanceState?
    @Environment(\.openWindow) private var openWindow

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
                .disabled(flow.isOnboarding)
        }
        CommandGroup(replacing: .newItem) {
            Button("New Tab") { tabs?.newTab() }
                .keyboardShortcut("t")
                .disabled(tabs == nil)
            Button("New Window") { openWindow(id: "workspace") }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(flow.isOnboarding)
            Divider()
            // Listed before the system's Close item, so ⌘W closes a tab first and the window with its last tab.
            Button("Close Tab") { if let tabs { tabs.close(tabs.current) } }
                .keyboardShortcut("w")
                .disabled(tabs == nil)
        }
        CommandGroup(before: .toolbar) {
            Button("Toggle Notion Sidebar") { workspace?.toggleSidebar() }
                .keyboardShortcut("\\")
                .disabled(flow.isOnboarding || workspace == nil)
            Button(appearance?.isShown == true ? "Hide Appearance" : "Show Appearance") { appearance?.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .control])
                .disabled(appearance == nil)
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
            Button("Show Previous Tab") { tabs?.selectPrevious() }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled((tabs?.tabs.count ?? 0) < 2)
            Button("Show Next Tab") { tabs?.selectNext() }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled((tabs?.tabs.count ?? 0) < 2)
            Divider()
        }
        CommandMenu("Theme") {
            ForEach(Array(store.choices.enumerated()), id: \.element.id) { index, theme in
                Toggle(theme.name, isOn: Binding(get: { store.activeID == theme.id }, set: { if $0 { store.activate(theme.id) } }))
                    .keyboardShortcut(index < 9 ? KeyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .control]) : nil)
            }
            Divider()
            Button("Customize Theme…") { appearance?.customize(store.selected) }
                .disabled(appearance == nil || !store.enabled)
            Button("New Theme…") { appearance?.newTheme(from: store.selected) }
                .disabled(appearance == nil)
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
                Picker("Theme", selection: $store.activeID) {
                    ForEach(store.choices) { theme in Text(theme.name).tag(theme.id) }
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
