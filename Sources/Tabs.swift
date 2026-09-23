import SwiftUI
import Combine

extension Workspace: Identifiable {}

/// A window's tabs, drawn in the header as in Notion's app. Each tab has its own web view; all share Notion's cookies.
@MainActor final class BrowserTabs: ObservableObject {
    @Published private(set) var tabs: [Workspace]
    @Published private(set) var current: Workspace
    /// The open pages and selected tab, encoded so the tabs can reopen at the next launch.
    @Published private(set) var snapshot = ""
    weak var window: NSWindow?
    private var styling: (theme: PotionTheme, enabled: Bool) = (PotionTheme.presets[0], false)
    private var subscriptions: [ObjectIdentifier: AnyCancellable] = [:]

    private struct Snapshot: Codable { var urls: [URL?]; var selected: Int }

    init() {
        let first = Workspace()
        tabs = [first]
        current = first
        configure(first)
    }

    @discardableResult
    func newTab(_ url: URL? = nil, select: Bool = true) -> Workspace {
        let tab = Workspace()
        configure(tab)
        tab.apply(styling.theme, enabled: styling.enabled)
        tabs.insert(tab, at: (tabs.firstIndex { $0 === current } ?? tabs.count - 1) + 1)
        tab.open(url ?? Workspace.homeURL)
        if select { current = tab }
        persist()
        return tab
    }
    func select(_ tab: Workspace) {
        guard tabs.contains(where: { $0 === tab }) else { return }
        current = tab
        persist()
    }
    /// Closes a tab, or the window when it is the last one.
    func close(_ tab: Workspace) {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0 === tab }) else { window?.performClose(nil); return }
        tab.webView.stopLoading()
        tabs.remove(at: index)
        subscriptions[ObjectIdentifier(tab)] = nil
        if current === tab { current = tabs[min(index, tabs.count - 1)] }
        persist()
    }
    func closeOthers(than tab: Workspace) {
        for other in tabs where other !== tab { close(other) }
    }
    func selectNext() { step(1) }
    func selectPrevious() { step(-1) }
    private func step(_ offset: Int) {
        guard let index = tabs.firstIndex(where: { $0 === current }) else { return }
        select(tabs[(index + offset + tabs.count) % tabs.count])
    }

    /// Applies the saved theme to every tab, and to tabs opened later.
    func apply(_ theme: PotionTheme, enabled: Bool) {
        styling = (theme, enabled)
        tabs.forEach { $0.apply(theme, enabled: enabled) }
    }
    /// Shows an unsaved theme on every tab while it's being edited; `restoreStyling` puts the saved one back.
    func preview(_ theme: PotionTheme) { tabs.forEach { $0.apply(theme, enabled: true) } }
    func restoreStyling() { apply(styling.theme, enabled: styling.enabled) }

    /// Reopens the tabs saved by `snapshot`, or the last page when there is nothing to restore.
    func restore(_ saved: String?) {
        guard let data = saved?.data(using: .utf8), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              !snapshot.urls.isEmpty else { current.open(); return }
        current.open(snapshot.urls[0])
        for url in snapshot.urls.dropFirst() { newTab(url, select: false) }
        select(tabs[min(max(snapshot.selected, 0), tabs.count - 1)])
    }

    private func configure(_ tab: Workspace) {
        tab.onOpenTab = { [weak self] url in self?.newTab(url, select: false) }
        subscriptions[ObjectIdentifier(tab)] = tab.$pageURL.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.persist() }
        }
    }
    private func persist() {
        let value = Snapshot(urls: tabs.map(\.pageURL), selected: tabs.firstIndex { $0 === current } ?? 0)
        if let data = try? JSONEncoder().encode(value), let string = String(data: data, encoding: .utf8), string != snapshot {
            snapshot = string
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

/// Reports a view's leading edge in window coordinates, so header items can line up with Notion's sidebar.
struct WindowXReader: NSViewRepresentable {
    @Binding var x: CGFloat

    func makeNSView(context: Context) -> ReaderView { ReaderView { x = $0 } }
    func updateNSView(_ view: ReaderView, context: Context) { view.report() }

    final class ReaderView: NSView {
        let onChange: (CGFloat) -> Void
        private var last: CGFloat = -1
        init(onChange: @escaping (CGFloat) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            postsFrameChangedNotifications = true
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); report() }
        override func layout() { super.layout(); report() }
        func report() {
            guard window != nil else { return }
            let x = convert(bounds, to: nil).minX.rounded()
            guard x != last else { return }
            last = x
            DispatchQueue.main.async { self.onChange(x) }
        }
    }
}
