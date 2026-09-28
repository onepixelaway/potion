import SwiftUI

extension Workspace: Identifiable {}

extension FocusedValues {
    /// The focused window's current tab, for menu commands.
    @Entry var workspace: Workspace?
}

/// A window's tabs, drawn in the header as in Notion's app. Each tab has its own web view; all share Notion's cookies.
@MainActor final class BrowserTabs: ObservableObject {
    @Published private(set) var tabs: [Workspace]
    @Published private(set) var current: Workspace
    weak var window: NSWindow?
    /// The theme every tab shows, including tabs opened later, or nil for Notion's own look.
    @Published private(set) var theme: PotionTheme?
    /// Notion's Mac-app layout, on once the person is in their workspace.
    var usesWindowLayout = false { didSet { tabs.forEach { $0.usesWindowLayout = usesWindowLayout } } }
    /// The last snapshot this window saved, so unchanged tabs don't overwrite another window's.
    private var savedSnapshot: Data?

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

    func newTab(_ url: URL? = nil, select: Bool = true) {
        let tab = Workspace()
        configure(tab)
        tab.apply(theme)
        tabs.insert(tab, at: (currentIndex ?? tabs.count - 1) + 1)
        tab.open(url ?? Workspace.homeURL)
        if select { current = tab }
        persist()
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

    func apply(_ theme: PotionTheme?) {
        self.theme = theme
        tabs.forEach { $0.apply(theme) }
    }

    /// Reopens the saved tabs, or the workspace when there is nothing to restore.
    func restore() {
        guard let data = defaults.data(forKey: Self.snapshotKey), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
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
        guard let data = try? JSONEncoder().encode(value), data != savedSnapshot else { return }
        savedSnapshot = data
        defaults.set(data, forKey: Self.snapshotKey)
    }
}
