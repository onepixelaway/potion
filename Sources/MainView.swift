import SwiftUI

struct MainView: View {
    @ObservedObject var store: ThemeStore
    @ObservedObject var tabs: BrowserTabs
    let workspace: Workspace
    @ObservedObject var appearance: AppearanceState

    var body: some View {
        // Notion fills the window up to the title bar, as in its own app; Potion's tab row sits over the page column.
        ZStack(alignment: .topLeading) {
            BrowserView(theme: tabs.styling.active, workspace: workspace)
            WindowHeader(tabs: tabs, workspace: workspace, appearance: appearance)
        }
        .ignoresSafeArea(edges: .top)
        // The title names the window in the Window menu; the header itself shows tabs.
        .navigationTitle(workspace.displayTitle)
        .hiddenTitleBar()
        .modifier(TitleBarHeight())
        // Header controls over the page follow the theme's light or dark appearance, including one being edited.
        .preferredColorScheme(tabs.styling.active.map { $0.isDark ? .dark : .light })
        .inspector(isPresented: $appearance.isShown) {
            AppearancePanel(store: store, appearance: appearance)
                .inspectorColumnWidth(min: 290, ideal: 310, max: 380)
        }
    }
}

/// Gives the window an empty compact toolbar, which makes the title bar tall enough to center the traffic lights in
/// Notion's sidebar row. It has no items, so every click along the title bar reaches the page or Potion's controls.
private struct TitleBarHeight: ViewModifier {
    func body(content: Content) -> some View {
        content.background(WindowAccessor { window in
            if window.toolbar == nil { window.toolbar = NSToolbar(identifier: "potion.titlebar") }
            window.toolbarStyle = .unifiedCompact
        })
    }
}

/// The title bar row, laid out like Notion's app. With the sidebar open, Notion's own sidebar row fills the space
/// over it: the collapse button just after the traffic lights, inbox and new page at its right. With the sidebar
/// collapsed, Potion's buttons stand in for those. Then come back and forward, the tabs, and the page actions.
private struct WindowHeader: View {
    @ObservedObject var tabs: BrowserTabs
    let workspace: Workspace
    @ObservedObject var appearance: AppearanceState

    private let buttonX = ThemeInjection.sidebarButtonX
    /// Notion's inbox and new-page buttons, with the row's end padding, at the right of its sidebar row.
    private let sidebarTrailingWidth: CGFloat = 72

    var body: some View {
        let sidebarWidth = workspace.sidebarWidth
        HStack(spacing: 0) {
            if sidebarWidth > 0 {
                // Empty stretches of Notion's row move the window; its buttons get the clicks.
                WindowDragArea().frame(width: buttonX - 2)
                Color.clear.frame(width: 32).allowsHitTesting(false)
                WindowDragArea().frame(width: max(0, sidebarWidth - buttonX - 30 - sidebarTrailingWidth))
                Color.clear.frame(width: min(sidebarWidth, sidebarTrailingWidth)).allowsHitTesting(false)
            } else {
                HStack(spacing: 8) {
                    HeaderIconButton(symbol: "sidebar.left", help: "Open sidebar (⌘\\)") { workspace.toggleSidebar() }
                    HeaderIconButton(symbol: "tray", help: "Inbox", badge: workspace.inboxCount) { workspace.openInbox() }
                    HeaderIconButton(symbol: "square.and.pencil", help: "New page") { workspace.newPage() }
                }
                .padding(.leading, buttonX)
                .frame(maxHeight: .infinity)
                .background(WindowDragArea())
                .overlay(alignment: .bottom) { HeaderRule(axis: .horizontal) }
            }
            pageRow
        }
        .frame(height: ThemeInjection.headerHeight)
    }

    private var pageRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                HeaderIconButton(symbol: "chevron.left", help: "Back (⌘[)", isEnabled: workspace.canGoBack) { workspace.goBack() }
                HeaderIconButton(symbol: "chevron.right", help: "Forward (⌘])", isEnabled: workspace.canGoForward) { workspace.goForward() }
            }
            .padding(.horizontal, 8)
            HeaderRule(axis: .vertical)
            TabStrip(tabs: tabs)
            HStack(spacing: 2) {
                HeaderIconButton(symbol: "arrow.clockwise", help: "Reload this page (⌘R)") { workspace.reload() }
                HeaderIconButton(symbol: "safari", help: "Open this page in your browser", isEnabled: workspace.canOpenInBrowser) { workspace.openInBrowser() }
                HeaderIconButton(symbol: "slider.horizontal.3", help: "Show or hide themes (⌃⌘I)", isOn: appearance.isShown) { appearance.toggle() }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxHeight: .infinity)
        .background(WindowDragArea())
        .overlay(alignment: .bottom) { HeaderRule(axis: .horizontal) }
    }
}

/// The hairlines that divide the title bar row, as in Notion's app.
private struct HeaderRule: View {
    let axis: Axis
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.09))
            .frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
    }
}

/// Moves the window when dragged, and zooms or minimizes it on double-click as the system setting asks.
private struct WindowDragArea: View {
    var body: some View {
        Color.clear
            .contentShape(.rect)
            .gesture(WindowDragGesture())
            .allowsWindowActivationEvents(true)
            .onTapGesture(count: 2) {
                guard let window = NSApp.keyWindow else { return }
                switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
                case "Minimize": window.miniaturize(nil)
                case "None": break
                default: window.performZoom(nil)
                }
            }
    }
}

/// Notion-style tabs: full-height cells divided by hairlines, a close button on hover, then a “+”.
private struct TabStrip: View {
    @ObservedObject var tabs: BrowserTabs

    var body: some View {
        GeometryReader { proxy in
            let tabWidth = ((proxy.size.width - 44) / CGFloat(tabs.tabs.count)).clamped(to: 72...170)
            HStack(spacing: 0) {
                ForEach(tabs.tabs) { tab in
                    TabItem(workspace: tab, isSelected: tab === tabs.current, tabs: tabs)
                        .frame(width: tabWidth)
                    HeaderRule(axis: .vertical)
                }
                HeaderIconButton(symbol: "plus", help: "New tab (⌘T)") { tabs.newTab() }
                    .padding(.horizontal, 6)
                // Empty space after the tabs moves the window, as in any title bar.
                WindowDragArea()
            }
            .animation(.snappy(duration: 0.2), value: tabs.tabs.map(\.id))
        }
    }
}

private struct TabItem: View {
    let workspace: Workspace
    let isSelected: Bool
    let tabs: BrowserTabs
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .trailing) {
            Text(workspace.displayTitle)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
                .padding(.trailing, isHovering ? 30 : 10)
            if isHovering {
                Button { tabs.close(workspace) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).frame(width: 18, height: 18)
                        .background(.primary.opacity(0.08), in: .rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
                .help("Close tab (⌘W)")
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(isSelected ? 0.05 : (isHovering ? 0.025 : 0)))
        .contentShape(.rect)
        .onTapGesture { tabs.select(workspace) }
        .onHover { isHovering = $0 }
        .help(workspace.displayTitle)
        .contextMenu {
            Button("Close Tab") { tabs.close(workspace) }
            Button("Close Other Tabs") { tabs.closeOthers(than: workspace) }
                .disabled(tabs.tabs.count < 2)
            Divider()
            Button("Open in Browser") { workspace.openInBrowser() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A flat header icon, like Notion's, with a soft hover highlight instead of a toolbar capsule.
private struct HeaderIconButton: View {
    let symbol: String
    let help: String
    var isEnabled = true
    var isOn = false
    var badge = 0
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .frame(width: 28, height: 28)
                .background(.primary.opacity(isOn ? 0.1 : (isHovering && isEnabled ? 0.07 : 0)), in: .rect(cornerRadius: 6))
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color(red: 0.86, green: 0.37, blue: 0.32), in: .capsule)
                            .offset(x: 5, y: -4)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? .primary : .secondary)
        .opacity(isEnabled ? 1 : 0.35)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
        .help(help)
        .accessibilityLabel(badge > 0 ? "\(help), \(badge) unread" : help)
    }
}

/// Everything about how Notion looks: the theme gallery, and the theme editor in place of it while editing.
private struct AppearancePanel: View {
    @ObservedObject var store: ThemeStore
    @ObservedObject var appearance: AppearanceState

    var body: some View {
        if let theme = appearance.editing {
            ThemeEditor(original: theme, store: store, appearance: appearance)
                .id(theme.id)
        } else {
            gallery
        }
    }

    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if appearance.isChoosingFirstTheme {
                    Text("Choose a Theme").font(.title2.bold())
                    Text("Pick a look for your workspace. You can change it anytime with the Appearance button.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                } else {
                    Text("Appearance").font(.title2.bold())
                }
                grid([PotionTheme.original] + PotionTheme.presets) { theme in
                    if !theme.isOriginal {
                        Button("Customize…") { edit(theme) }
                    }
                }
                .padding(.top, 20)
                if !store.customs.isEmpty {
                    Text("My Themes").font(.headline).padding(.top, 28)
                    grid(store.customs) { theme in
                        Button("Edit…") { edit(theme) }
                        Button("Duplicate") { appearance.newTheme(from: theme) }
                        Divider()
                        Button("Delete", role: .destructive) { withAnimation { store.delete(theme) } }
                    }
                    .padding(.top, 12)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.never)
        .bottomBar {
            HStack {
                Button("Customize…") { appearance.customize(store.selected) }
                    .disabled(!store.enabled)
                    .help("Edit the fonts and colors of the current theme")
                Spacer()
                Button { appearance.newTheme(from: store.selected) } label: { Label("New Theme", systemImage: "plus") }
                    .help("Mix a new theme from the current one")
            }
            .padding(16)
        }
    }

    private func edit(_ theme: PotionTheme) {
        store.select(theme)
        appearance.customize(theme)
    }

    private func grid(_ themes: [PotionTheme], @ViewBuilder menu: @escaping (PotionTheme) -> some View) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], spacing: 18) {
            ForEach(themes) { theme in
                ThemeCard(theme: theme, isSelected: store.activeID == theme.id) {
                    withAnimation(.snappy) { store.activate(theme.id) }
                    appearance.themeChosen()
                }
                .contextMenu { menu(theme) }
            }
        }
    }
}

private struct BrowserView: View {
    let theme: PotionTheme?
    let workspace: Workspace

    var body: some View {
        WebViewHost(webView: workspace.webView)
            // Matches the page color so switching pages never flashes white under a dark theme.
            .background(theme.map { Color(hex: $0.background) } ?? Color(nsColor: .textBackgroundColor))
            .overlay(alignment: .top) {
                LoadingBar(workspace: workspace)
                    .padding(.top, ThemeInjection.headerHeight)
            }
            .overlay {
                if let error = workspace.error {
                    ContentUnavailableView {
                        Label("Can’t Open This Page", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") { workspace.reload() }
                            .keyboardShortcut(.defaultAction)
                        Button("Open in Browser") { workspace.openInBrowser() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
                }
            }
    }
}

/// A thin Safari-style progress line along the top of the page. The only view in the window that reads progress,
/// so loading redraws just this line.
private struct LoadingBar: View {
    let workspace: Workspace

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.tint)
                .frame(width: proxy.size.width * max(0.05, workspace.progress), height: 2)
                .animation(.easeOut(duration: 0.25), value: workspace.progress)
        }
        .frame(height: 2)
        .opacity(workspace.isLoading ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: workspace.isLoading)
        .accessibilityHidden(true)
    }
}
