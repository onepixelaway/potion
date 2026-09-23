import SwiftUI

struct WelcomeView: View {
    @ObservedObject var flow: AppFlow

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
            Text("Welcome to Potion")
                .font(.system(size: 38, weight: .bold))
                .padding(.top, 14)
            Text("Your Notion workspace, dressed for the Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 22) {
                FeatureRow(symbol: "macwindow", title: "At home on your Mac",
                           detail: "Notion in its own window, with real menus, keyboard shortcuts and swipe navigation.")
                FeatureRow(symbol: "textformat", title: "Typography you’ll enjoy",
                           detail: "Curated themes pair expressive headings with easy-reading body text.")
                FeatureRow(symbol: "paintpalette", title: "Make it your own",
                           detail: "Mix fonts and colors and watch your pages change as you go.")
                FeatureRow(symbol: "lock.shield", title: "Private by design",
                           detail: "You sign in on Notion’s own page. Potion never sees your password.")
            }
            .frame(maxWidth: 460)
            .padding(.top, 40)
            Spacer(minLength: 24)
            Button { flow.go(to: .signIn) } label: {
                Text("Continue").frame(minWidth: 220)
            }
            .prominentStyle()
            .controlSize(.extraLarge)
            .keyboardShortcut(.defaultAction)
            Text("Potion is independent and not affiliated with Notion.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onboardingChrome()
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.tint)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SignInView: View {
    @ObservedObject var workspace: Workspace
    @ObservedObject var flow: AppFlow

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button { flow.go(to: .welcome) } label: { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.borderless)
                Spacer()
                Text("Sign in to Notion")
                    .font(.system(size: 32, weight: .bold))
                Text("Potion opens your workspace as soon as you’re signed in, ready for you to pick a theme.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                VStack(alignment: .leading, spacing: 18) {
                    FeatureRow(symbol: "lock.shield", title: "Your password stays with Notion",
                               detail: "You’re on Notion’s own sign-in page. Potion never sees what you type there.")
                    FeatureRow(symbol: "person.badge.key", title: "Email, Google, Apple or Microsoft",
                               detail: "If a passkey or company sign-in doesn’t work here, continue with email.")
                }
                .padding(.top, 32)
                Spacer()
                Spacer()
            }
            .frame(width: 330)
            .padding(.horizontal, 36)
            .padding(.vertical, 20)
            WebCard(workspace: workspace)
                .padding([.top, .bottom, .trailing], 20)
        }
        .onboardingChrome()
    }
}

/// The live Notion web view, framed as a page floating in the onboarding window.
private struct WebCard: View {
    @ObservedObject var workspace: Workspace

    var body: some View {
        WebViewHost(webView: workspace.webView, cornerRadius: 14)
            .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 14))
            .overlay {
                if workspace.isLoading && workspace.progress < 0.5 { ProgressView().controlSize(.large) }
                if let error = workspace.error {
                    ContentUnavailableView {
                        Label("Can’t Reach Notion", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") { workspace.reload() }
                    }
                    .background(.background, in: .rect(cornerRadius: 14))
                }
            }
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.separator) }
            .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
    }
}

extension View {
    /// Onboarding fills the window edge to edge: no title or toolbar, over a translucent window background.
    func onboardingChrome() -> some View {
        toolbar(removing: .title)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .containerBackground(.thickMaterial, for: .window)
    }

    /// Pins controls below scrolling content, separated by a divider, so nothing scrolls underneath them.
    func bottomBar(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 0) {
            self
            Divider()
            content()
        }
    }

    /// The primary action in a view: Liquid Glass on macOS 26, a filled button before that.
    @ViewBuilder func prominentStyle() -> some View {
        if #available(macOS 26, *) { buttonStyle(.glassProminent) } else { buttonStyle(.borderedProminent) }
    }
}
