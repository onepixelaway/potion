import SwiftUI

extension Workspace: Identifiable {}

extension FocusedValues {
    /// The focused window's current tab, for menu commands.
    @Entry var workspace: Workspace?
}

/// The theme a window's tabs show, and whether it's on.
struct ThemeStyling: Equatable {
    var theme: PotionTheme
    var enabled: Bool
    /// The theme restyling Notion, or nil for Notion's own look.
    var active: PotionTheme? { enabled ? theme : nil }
}

/// A window's tabs, drawn in the header as in Notion's app. Each tab has its own web view; all share Notion's cookies.
@MainActor final class BrowserTabs: ObservableObject {
    @Published private(set) var tabs: [Workspace]
    @Published private(set) var current: Workspace
    weak var window: NSWindow?
    /// What every tab shows, including tabs opened later.
    @Published private(set) var styling = ThemeStyling(theme: .standard, enabled: false)
    /// Notion's Mac-app layout, on once the person is in their workspace.
    var usesWindowLayout = false { didSet { tabs.forEach { $0.usesWindowLayout = usesWindowLayout } } }
    /// The last snapshot this window saved, so unchanged tabs don't overwrite another window's.
    private var savedSnapshot = ""

    /// The open pages and selected tab, saved so the most recently changed window's tabs reopen at the next launch.
    private struct Snapshot: Codable { var urls: [URL?]; var selected: Int }
    private static let snapshotKey = "potion.tabs"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        tabs.insert(tab, at: (currentIndex ?? tabs.count - 1) + 1)
        tab.open(url ?? Workspace.homeURL)
        if select { current = tab }
        persist()
        return tab
    }
    func select(_ tab: Workspace) {
        guard tabs.contains(tab) else { return }
        current = tab
        persist()
    }
    /// Closes a tab, or the window when it is the last one.
    func close(_ tab: Workspace) {
        guard tabs.count > 1, let index = tabs.firstIndex(of: tab) else { window?.performClose(nil); return }
        tab.webView.stopLoading()
        tab.onPageChange = nil
        tabs.remove(at: index)
        if current === tab { current = tabs[min(index, tabs.count - 1)] }
        persist()
    }
    func closeOthers(than tab: Workspace) {
        for other in tabs where other !== tab { close(other) }
    }
    func selectNext() { step(1) }
    func selectPrevious() { step(-1) }
    private var currentIndex: Int? { tabs.firstIndex(of: current) }
    private func step(_ offset: Int) {
        guard let index = currentIndex else { return }
        select(tabs[(index + offset + tabs.count) % tabs.count])
    }

    func apply(_ styling: ThemeStyling) {
        self.styling = styling
        tabs.forEach { $0.apply(styling.theme, enabled: styling.enabled) }
    }

    /// Reopens the saved tabs, or the last page when there is nothing to restore.
    func restore() {
        guard let data = defaults.string(forKey: Self.snapshotKey)?.data(using: .utf8), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              !snapshot.urls.isEmpty else { current.open(); return }
        current.open(snapshot.urls[0])
        for url in snapshot.urls.dropFirst() { newTab(url, select: false) }
        select(tabs[snapshot.selected.clamped(to: 0...(tabs.count - 1))])
    }

    private func configure(_ tab: Workspace) {
        tab.onOpenTab = { [weak self] url in self?.newTab(url, select: false) }
        tab.usesWindowLayout = usesWindowLayout
        tab.onPageChange = { [weak self] in self?.persist() }
    }
    private func persist() {
        let value = Snapshot(urls: tabs.map(\.pageURL), selected: currentIndex ?? 0)
        guard let data = try? JSONEncoder().encode(value), let string = String(data: data, encoding: .utf8), string != savedSnapshot else { return }
        savedSnapshot = string
        defaults.set(string, forKey: Self.snapshotKey)
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
