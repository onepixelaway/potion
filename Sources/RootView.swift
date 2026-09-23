import SwiftUI

/// One Potion window or tab: its own Notion web view and Appearance panel, over the app-wide onboarding flow.
struct RootView: View {
    let request: TabRequest
    @ObservedObject var store: ThemeStore
    @ObservedObject var flow: AppFlow
    @StateObject private var workspace = Workspace()
    @StateObject private var appearance = AppearanceState()
    @SceneStorage("potion.pageURL") private var savedPageURL: String?
    @Environment(\.openWindow) private var openWindow
    @State private var window: NSWindow?

    private struct Styling: Equatable { var theme: PotionTheme; var enabled: Bool }
    private var styling: Styling { Styling(theme: store.selected, enabled: store.enabled && flow.showsThemes) }

    var body: some View {
        ZStack {
            switch flow.stage {
            case .welcome: WelcomeView(flow: flow).transition(.opacity)
            case .signIn: SignInView(workspace: workspace, flow: flow).transition(.opacity)
            case .ready: MainView(store: store, workspace: workspace, appearance: appearance).transition(.opacity)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .background(WindowAccessor { window in
            guard self.window !== window else { return }
            self.window = window
            flow.register(window)
            Tabs.adopt(window, for: request)
        })
        .focusedSceneObject(workspace)
        .focusedSceneObject(appearance)
        .task {
            workspace.onOpenTab = { url in Tabs.open(url, from: window, using: openWindow) }
            guard workspace.webView.url == nil else { return }
            if flow.stage != .ready {
                workspace.openLogin()
            } else {
                let saved = savedPageURL.flatMap(URL.init(string:))
                workspace.open(saved ?? request.url ?? (request.asTab ? Workspace.homeURL : nil))
            }
        }
        .onChange(of: styling, initial: true) { _, styling in workspace.apply(styling.theme, enabled: styling.enabled) }
        .onChange(of: workspace.isSignedIn) { _, signedIn in flow.signInChanged(signedIn) }
        .onChange(of: workspace.pageURL) { _, url in savedPageURL = url?.absoluteString }
        .onChange(of: flow.stage) { old, stage in
            switch (old, stage) {
            case (.welcome, .signIn) where workspace.isSignedIn:
                // Someone who is already signed in goes straight to their workspace.
                flow.completeOnboarding()
            case (.signIn, .ready):
                appearance.beginFirstThemeChoice()
            case (.ready, .signIn):
                appearance.isShown = false
                if let keeper = flow.keeperWindow, keeper !== window { window?.close() } else { workspace.returnToLogin() }
            default:
                break
            }
        }
        .sheet(item: $workspace.authPopup) { popup in
            AuthSheet(popup: popup, workspace: workspace)
        }
    }
}

/// A sign-in popup (Google, Apple, Microsoft) presented as a sheet over the window that opened it.
private struct AuthSheet: View {
    let popup: AuthPopup
    let workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
                Text("Sign in to Notion").font(.headline)
                Spacer()
                Button("Cancel") { workspace.closeAuthPopup() }.keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
            WebViewHost(webView: popup.webView)
        }
        .frame(width: 560, height: 700)
        .interactiveDismissDisabled()
    }
}
