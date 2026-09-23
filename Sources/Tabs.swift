import SwiftUI

/// Identifies one Potion window. Every request is unique, so opening one always makes a new window or tab.
struct TabRequest: Codable, Hashable {
    var id = UUID()
    /// The Notion page to open, or nil for the last page (a new window) or Notion's home (a new tab).
    var url: URL?
    /// Whether the window should join the current window's tab group.
    var asTab = false
}

/// Native macOS window tabs. Each tab is its own window with its own web view; they share Notion's cookies.
@MainActor enum Tabs {
    private static weak var pendingParent: NSWindow?

    static func open(_ url: URL?, from window: NSWindow?, using openWindow: OpenWindowAction) {
        pendingParent = window ?? NSApp.keyWindow
        openWindow(value: TabRequest(url: url, asTab: true))
    }
    static func openWindow(using openWindow: OpenWindowAction) {
        pendingParent = nil
        openWindow(value: TabRequest())
    }

    /// Called as soon as a window's content is attached, before the window is shown.
    static func adopt(_ window: NSWindow, for request: TabRequest) {
        // AppKit tabs a "preferred" window into the key window's group as it appears. Tabs restored at
        // launch are also "preferred", so they regroup; explicit new windows stay separate.
        window.tabbingMode = request.asTab ? .preferred : .disallowed
        let parent = pendingParent
        pendingParent = nil
        DispatchQueue.main.async {
            if request.asTab, let parent, parent !== window, parent.tabGroup?.windows.contains(window) != true {
                parent.addTabbedWindow(window, ordered: .above)
                window.makeKeyAndOrderFront(nil)
            }
            // Back to the system default, so people can still merge or split windows themselves.
            window.tabbingMode = .automatic
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
