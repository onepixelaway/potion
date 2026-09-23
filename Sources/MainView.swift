import SwiftUI

struct MainView: View {
    @ObservedObject var store: ThemeStore
    @ObservedObject var tabs: BrowserTabs
    @ObservedObject var workspace: Workspace
    @ObservedObject var appearance: AppearanceState

    var body: some View {
        GeometryReader { proxy in
            BrowserView(store: store, workspace: workspace)
                .background { HeaderBackdrop(chrome: workspace.chrome, fallback: pageFallback).ignoresSafeArea() }
                // The title names the window in the Window menu; the header itself shows tabs, as Notion's does.
                .navigationTitle(workspace.displayTitle)
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .modifier(HeaderToolbar(tabs: tabs, workspace: workspace, appearance: appearance, contentWidth: proxy.size.width))
        }
        // Header controls over the page follow the theme's light or dark appearance.
        .preferredColorScheme(store.enabled ? (store.selected.isDark ? .dark : .light) : nil)
        .inspector(isPresented: $appearance.isShown) {
            AppearancePanel(store: store, tabs: tabs, appearance: appearance)
                .inspectorColumnWidth(min: 290, ideal: 310, max: 380)
        }
    }

    private var pageFallback: Color {
        store.enabled ? Color(hex: store.selected.background) : Color(nsColor: .textBackgroundColor)
    }
}

/// The header, laid out like Notion's app: sidebar toggle over the sidebar; back, forward and tabs from the
/// sidebar's edge; page actions on the right. Flat controls, without toolbar glass, so it reads as part of Notion.
private struct HeaderToolbar: ViewModifier {
    @ObservedObject var tabs: BrowserTabs
    @ObservedObject var workspace: Workspace
    @ObservedObject var appearance: AppearanceState
    let contentWidth: CGFloat
    @State private var stripX: CGFloat = 80

    /// Room for the actions group on the right.
    private let actionsWidth: CGFloat = 112

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.toolbar {
                ToolbarItem(placement: .navigation) { strip }.sharedBackgroundVisibility(.hidden)
                ToolbarSpacer(.flexible)
                ToolbarItem(placement: .primaryAction) { actions }.sharedBackgroundVisibility(.hidden)
            }
        } else {
            content.toolbar {
                ToolbarItem(placement: .navigation) { strip }
                ToolbarItem(placement: .primaryAction) { actions }
            }
        }
    }

    private var strip: some View {
        let sidebarGap = max(6, workspace.chrome.sidebarWidth + 6 - stripX - 30)
        return HStack(spacing: 2) {
            WindowXReader(x: $stripX).frame(width: 0, height: 0)
            HeaderIconButton(symbol: "sidebar.left", help: "Show or hide Notion’s sidebar (⌘\\)") { workspace.toggleSidebar() }
            Color.clear.frame(width: sidebarGap, height: 1)
            HeaderIconButton(symbol: "chevron.left", help: "Back (⌘[)", isEnabled: workspace.canGoBack) { workspace.goBack() }
            HeaderIconButton(symbol: "chevron.right", help: "Forward (⌘])", isEnabled: workspace.canGoForward) { workspace.goForward() }
            TabStrip(tabs: tabs, width: max(120, contentWidth - stripX - sidebarGap - 130 - actionsWidth))
                .padding(.leading, 6)
        }
        .frame(height: 30)
    }

    private var actions: some View {
        HStack(spacing: 2) {
            HeaderIconButton(symbol: "arrow.clockwise", help: "Reload this page (⌘R)") { workspace.reload() }
            HeaderIconButton(symbol: "safari", help: "Open this page in your browser", isEnabled: workspace.canOpenInBrowser) { workspace.openInBrowser() }
            HeaderIconButton(symbol: "slider.horizontal.3", help: "Show or hide themes (⌃⌘I)", isOn: appearance.isShown) {
                withAnimation(.smooth) { appearance.isShown.toggle() }
            }
        }
        .frame(height: 30)
    }
}

/// Notion-style tabs: flat and equal width, with a close button on hover, then a “+”.
private struct TabStrip: View {
    @ObservedObject var tabs: BrowserTabs
    let width: CGFloat

    var body: some View {
        let tabWidth = min(190, max(64, (width - 34) / CGFloat(tabs.tabs.count)))
        HStack(spacing: 0) {
            ForEach(Array(tabs.tabs.enumerated()), id: \.element.id) { index, tab in
                let isSelected = tab === tabs.current
                let nextIsSelected = index + 1 < tabs.tabs.count && tabs.tabs[index + 1] === tabs.current
                TabItem(workspace: tab, isSelected: isSelected, tabs: tabs)
                    .frame(width: tabWidth)
                    .overlay(alignment: .trailing) {
                        if !isSelected && !nextIsSelected && index < tabs.tabs.count - 1 {
                            Rectangle().fill(.primary.opacity(0.1)).frame(width: 1, height: 14)
                        }
                    }
            }
            HeaderIconButton(symbol: "plus", help: "New tab (⌘T)") { tabs.newTab() }
                .padding(.leading, 4)
            Spacer(minLength: 0)
        }
        .frame(width: width, alignment: .leading)
        .animation(.snappy(duration: 0.2), value: tabs.tabs.map(\.id))
    }
}

private struct TabItem: View {
    @ObservedObject var workspace: Workspace
    let isSelected: Bool
    let tabs: BrowserTabs
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .trailing) {
            Text(workspace.displayTitle)
                .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                .padding(.trailing, isHovering ? 26 : 8)
            if isHovering {
                Button { tabs.close(workspace) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).frame(width: 18, height: 18)
                        .background(.primary.opacity(0.08), in: .rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.trailing, 6)
                .help("Close tab (⌘W)")
            }
        }
        .frame(height: 28)
        .background(Color.primary.opacity(isSelected ? 0.09 : (isHovering ? 0.045 : 0)), in: .rect(cornerRadius: 7))
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
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .regular))
                .frame(width: 28, height: 28)
                .background(.primary.opacity(isOn ? 0.1 : (isHovering && isEnabled ? 0.07 : 0)), in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? .primary : .secondary)
        .opacity(isEnabled ? 1 : 0.35)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Paints the window header in Notion's own colors: the sidebar's color above Notion's sidebar, the page's color
/// above the page, so the header and Notion read as one surface as they do in Notion's app.
private struct HeaderBackdrop: View {
    let chrome: PageChrome
    let fallback: Color

    var body: some View {
        let page = chrome.pageColor.map(Color.init(nsColor:)) ?? fallback
        HStack(spacing: 0) {
            if chrome.sidebarWidth > 0 {
                (chrome.sidebarColor.map(Color.init(nsColor:)) ?? page)
                    .frame(width: chrome.sidebarWidth)
                    .overlay(alignment: .trailing) { Rectangle().fill(.primary.opacity(0.07)).frame(width: 1) }
            }
            page
        }
        .animation(.smooth(duration: 0.2), value: chrome)
    }
}

/// Everything about how Notion looks: the theme gallery, and the theme editor in place of it while editing.
private struct AppearancePanel: View {
    @ObservedObject var store: ThemeStore
    @ObservedObject var tabs: BrowserTabs
    @ObservedObject var appearance: AppearanceState

    var body: some View {
        if let theme = appearance.editing {
            ThemeEditor(original: theme, tabs: tabs, store: store, appearance: appearance)
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
                        Button("Customize…") { store.select(theme); appearance.customize(theme) }
                    }
                }
                .padding(.top, 20)
                if !store.customs.isEmpty {
                    Text("My Themes").font(.headline).padding(.top, 28)
                    grid(store.customs) { theme in
                        Button("Edit…") { store.select(theme); appearance.customize(theme) }
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
    @ObservedObject var store: ThemeStore
    @ObservedObject var workspace: Workspace

    var body: some View {
        WebViewHost(webView: workspace.webView)
            // Matches the page color so switching pages never flashes white under a dark theme.
            .background(store.enabled ? Color(hex: store.selected.background) : Color(nsColor: .textBackgroundColor), ignoresSafeAreaEdges: [])
            .overlay(alignment: .top) { LoadingBar(isLoading: workspace.isLoading, progress: workspace.progress) }
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

/// A thin Safari-style progress line along the top of the page.
private struct LoadingBar: View {
    let isLoading: Bool
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.tint)
                .frame(width: proxy.size.width * max(0.05, progress), height: 2)
                .animation(.easeOut(duration: 0.25), value: progress)
        }
        .frame(height: 2)
        .opacity(isLoading ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: isLoading)
        .accessibilityHidden(true)
    }
}
