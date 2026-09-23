import SwiftUI

/// One Potion window: its tabs and Appearance panel, over the app-wide onboarding flow. The most recently
/// changed window's tabs are saved and reopen at launch.
struct RootView: View {
    @ObservedObject var store: ThemeStore
    @ObservedObject var flow: AppFlow
    @StateObject private var tabs = BrowserTabs()
    @StateObject private var appearance = AppearanceState()

    /// Themes restyle Notion only after sign-in, so the login page always looks like Notion's own.
    private var styling: ThemeStyling { ThemeStyling(theme: store.selected, enabled: store.enabled && !flow.isOnboarding) }

    var body: some View {
        WindowContent(store: store, flow: flow, tabs: tabs, workspace: tabs.current, appearance: appearance)
            .frame(minWidth: 900, minHeight: 620)
            .background(WindowAccessor { window in
                guard tabs.window !== window else { return }
                tabs.window = window
                flow.register(window)
            })
            .focusedSceneObject(tabs)
            .focusedSceneObject(appearance)
            .task {
                guard tabs.current.webView.url == nil else { return }
                if flow.isOnboarding { tabs.current.openLogin() } else { tabs.restore() }
            }
            .onChange(of: styling, initial: true) { _, styling in tabs.apply(styling) }
            .onChange(of: flow.stage, initial: true) { old, stage in
                tabs.usesWindowLayout = stage == .ready
                switch (old, stage) {
                case (.welcome, .signIn) where tabs.current.isSignedIn:
                    // Someone who is already signed in goes straight to their workspace.
                    flow.completeOnboarding()
                case (.signIn, .ready):
                    appearance.beginFirstThemeChoice()
                case (.ready, .signIn):
                    appearance.isShown = false
                    tabs.closeOthers(than: tabs.current)
                    tabs.current.returnToLogin()
                default:
                    break
                }
            }
    }
}

/// The window's content for the selected tab, observing that tab's workspace.
private struct WindowContent: View {
    @ObservedObject var store: ThemeStore
    @ObservedObject var flow: AppFlow
    @ObservedObject var tabs: BrowserTabs
    @ObservedObject var workspace: Workspace
    @ObservedObject var appearance: AppearanceState

    var body: some View {
        ZStack {
            switch flow.stage {
            case .welcome: WelcomeView(flow: flow).transition(.opacity)
            case .signIn: SignInView(workspace: workspace, flow: flow).transition(.opacity)
            case .ready: MainView(store: store, tabs: tabs, workspace: workspace, appearance: appearance).transition(.opacity)
            }
        }
        .focusedSceneObject(workspace)
        .onChange(of: workspace.isSignedIn) { _, signedIn in flow.signInChanged(signedIn) }
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
