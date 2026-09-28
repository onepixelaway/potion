import SwiftUI

/// Shown over a web view whose page couldn't load, with a way to try again.
struct PageErrorView: View {
    let title: String
    let error: String
    let workspace: Workspace
    var offersBrowser = false

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "wifi.exclamationmark")
        } description: {
            Text(error)
        } actions: {
            Button("Try Again") { workspace.reload() }
                .keyboardShortcut(.defaultAction)
            if offersBrowser { Button("Open in Browser") { workspace.openInBrowser() } }
        }
    }
}

/// Reports the NSWindow hosting a SwiftUI view as soon as the view joins it.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> AccessorView { AccessorView(onWindow: onWindow) }
    func updateNSView(_ view: AccessorView, context: Context) {}

    final class AccessorView: NSView {
        let onWindow: (NSWindow) -> Void
        init(onWindow: @escaping (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow(window) }
        }
    }
}

extension View {
    /// Onboarding fills the window edge to edge: no title or toolbar, over a translucent window background.
    func onboardingChrome() -> some View {
        hiddenTitleBar().containerBackground(.thickMaterial, for: .window)
    }

    /// No window title or toolbar background, so content reaches the top edge.
    func hiddenTitleBar() -> some View {
        toolbar(removing: .title).toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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
