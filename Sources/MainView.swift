import SwiftUI

struct MainView: View {
    @ObservedObject var store: ThemeStore
    @ObservedObject var workspace: Workspace
    @ObservedObject var appearance: AppearanceState

    var body: some View {
        BrowserView(store: store, workspace: workspace)
            .background { HeaderBackdrop(chrome: workspace.chrome, fallback: pageFallback).ignoresSafeArea() }
            // The title names the window's tab; the header itself stays clear, like Notion's, since the page shows its breadcrumb.
            .navigationTitle(workspace.displayTitle)
            .toolbar(removing: .title)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            // Buttons over the page follow the theme's light or dark appearance.
            .preferredColorScheme(store.enabled ? (store.selected.isDark ? .dark : .light) : nil)
            .inspector(isPresented: $appearance.isShown) {
                AppearancePanel(store: store, workspace: workspace, appearance: appearance)
                    .inspectorColumnWidth(min: 290, ideal: 310, max: 380)
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Notion Sidebar", systemImage: "sidebar.left") { workspace.toggleSidebar() }
                        .help("Show or hide Notion’s sidebar (⌘\\)")
                    Button("Back", systemImage: "chevron.left") { workspace.goBack() }
                        .disabled(!workspace.canGoBack)
                        .help("Go back (⌘[)")
                    Button("Forward", systemImage: "chevron.right") { workspace.goForward() }
                        .disabled(!workspace.canGoForward)
                        .help("Go forward (⌘])")
                }
                // Without a title the compact toolbar packs every item to the left; this pushes the rest to the right.
                if #available(macOS 26, *) {
                    ToolbarSpacer(.flexible)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Reload", systemImage: "arrow.clockwise") { workspace.reload() }
                        .help("Reload this page (⌘R)")
                    Button("Open in Browser", systemImage: "safari") { workspace.openInBrowser() }
                        .disabled(!workspace.canOpenInBrowser)
                        .help("Open this page in your browser")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Appearance", systemImage: "slider.horizontal.3") {
                        withAnimation(.smooth) { appearance.isShown.toggle() }
                    }
                    .help("Show or hide themes (⌃⌘I)")
                }
            }
    }

    private var pageFallback: Color {
        store.enabled ? Color(hex: store.selected.background) : Color(nsColor: .textBackgroundColor)
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
    @ObservedObject var workspace: Workspace
    @ObservedObject var appearance: AppearanceState

    var body: some View {
        if let theme = appearance.editing {
            ThemeEditor(original: theme, workspace: workspace, store: store, appearance: appearance)
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
