import XCTest
import WebKit
@testable import Potion

final class PotionTests: XCTestCase {
    /// Throwaway defaults, removed when the test ends.
    private func makeDefaults() -> UserDefaults {
        let suite = "PotionTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return UserDefaults(suiteName: suite)!
    }
    private func preset(_ id: String) -> PotionTheme { PotionTheme.preset(id: id)! }
    /// Shows the offline preview in a workspace and waits for it to finish loading.
    @MainActor private func loadPreview(_ workspace: Workspace) async {
        workspace.showPreview()
        let loaded = NSPredicate { _, _ in workspace.webView.url?.isFileURL == true && !workspace.webView.isLoading }
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: loaded, object: nil)], timeout: 15)
    }
    @MainActor private func js(_ source: String, in workspace: Workspace) async throws -> Any? {
        try await workspace.webView.evaluateJavaScript(source)
    }
    /// WCAG contrast ratio between two hex colors.
    private func contrast(_ first: String, _ second: String) -> Double {
        func luminance(_ hex: String) -> Double {
            let color = NSColor(hex: hex)
            let channels = [color.redComponent, color.greenComponent, color.blueComponent].map { value -> Double in
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
        }
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
    func testPaletteValidationRejectsCSSAndClampsType() {
        var theme = preset("paper")
        theme.colors.background = "red; } body {display:none}"
        theme.colors.accent = "#abc123"
        theme.colors.title = "#12345"
        theme.fonts.heading = "fake'; url(evil)"
        theme.fontSize = 500
        theme.lineHeight = 0
        let result = theme.validated
        XCTAssertEqual(result.colors.background, "F8F5EF")
        XCTAssertEqual(result.colors.accent, "ABC123")
        XCTAssertEqual(result.colors.title, "4B672A")
        XCTAssertEqual(result.fonts.heading, "Lora")
        XCTAssertEqual(result.fontSize, 22)
        XCTAssertEqual(result.lineHeight, 1.3)
        XCTAssertNil(PotionTheme.cleanHex("１２３４５６"))
    }
    func testNavigationHostBoundaries() {
        for address in ["https://www.notion.so/test", "https://team.notion.site/page", "https://notion.so", "https://app.notion.com/login"] {
            XCTAssertTrue(NavigationPolicy.isNotion(URL(string: address)!))
        }
        for address in ["https://notion.so.evil.com", "https://evilnotion.so", "https://app.notion.com.evil.com", "http://notion.so", "file:///etc/passwd"] {
            XCTAssertFalse(NavigationPolicy.isNotion(URL(string: address)!))
        }
        XCTAssertFalse(NavigationPolicy.canOpenExternally(URL(string: "javascript:alert(1)")!))
    }
    func testSignInPopupsAndRedirectsStayInPotion() {
        let login = URL(string: "https://app.notion.com/login")!
        let popupCheck = URL(string: "https://app.notion.com/verifyNoPopupBlockerHtmlAndRedirect?redirectUri=x")!
        // Notion's OAuth popup is on Notion's own domain and must not replace the login page.
        XCTAssertTrue(NavigationPolicy.isSignInPopup(popupCheck, hasWindowSize: false))
        XCTAssertTrue(NavigationPolicy.isSignInPopup(URL(string: "https://app.notion.com/anything")!, hasWindowSize: true))
        XCTAssertFalse(NavigationPolicy.isSignInPopup(URL(string: "https://app.notion.com/Team-Page-abc123")!, hasWindowSize: false))
        XCTAssertEqual(NavigationPolicy.decision(for: URL(string: "https://appleid.apple.com/auth/authorize")!, isLinkClick: false, from: login), .allow)
        XCTAssertEqual(NavigationPolicy.decision(for: URL(string: "https://acme.okta.com/sso")!, isLinkClick: false, from: login), .allow)
        XCTAssertEqual(NavigationPolicy.decision(for: URL(string: "https://example.com")!, isLinkClick: true, from: login), .openExternally)
        XCTAssertEqual(NavigationPolicy.decision(for: URL(string: "https://acme.okta.com/help")!, isLinkClick: true, from: URL(string: "https://acme.okta.com/sso")!), .allow)
        XCTAssertEqual(NavigationPolicy.decision(for: URL(string: "javascript:alert(1)")!, isLinkClick: true, from: login), .cancel)
        // Popups start on Notion or a known provider, then may follow the provider's redirects.
        XCTAssertEqual(NavigationPolicy.popupDecision(for: popupCheck, from: nil), .allow)
        XCTAssertEqual(NavigationPolicy.popupDecision(for: URL(string: "https://example.com")!, from: URL(string: "about:blank")!), .openExternally)
        XCTAssertEqual(NavigationPolicy.popupDecision(for: URL(string: "https://login.live.com/oauth")!, from: nil), .allow)
        XCTAssertEqual(NavigationPolicy.popupDecision(for: URL(string: "https://accounts.youtube.com/x")!, from: URL(string: "https://accounts.google.com/v3/signin")!), .allow)
    }
    func testWorkspaceDetectionMarksSignInComplete() {
        for address in ["https://app.notion.com/login", "https://app.notion.com/", "https://app.notion.com/onboarding",
                        "https://app.notion.com/googlepopupredirect?x=1", "https://app.notion.com/googlepopupcallback",
                        "https://team.notion.site/Public-Page", "https://accounts.google.com/x",
                        "https://www.notion.com/help", "https://notion.com/product"] {
            XCTAssertFalse(NavigationPolicy.isWorkspacePage(URL(string: address)!), address)
        }
        for address in ["https://app.notion.com/My-Page-0123456789abcdef", "https://www.notion.so/acme/Roadmap-abc"] {
            XCTAssertTrue(NavigationPolicy.isWorkspacePage(URL(string: address)!), address)
        }
        XCTAssertFalse(NavigationPolicy.isRestorable(URL(string: "https://app.notion.com/note/46846d11-8bb2")!))
        XCTAssertTrue(NavigationPolicy.isRestorable(URL(string: "https://app.notion.com/p/me/Page-cf3fbe84")!))
    }
    @MainActor func testSignInFlowPersistsAndSignOutResets() {
        let defaults = makeDefaults()
        let flow = AppFlow(defaults: defaults)
        XCTAssertEqual(flow.stage, .welcome)
        flow.signInChanged(true)
        XCTAssertEqual(flow.stage, .welcome, "Signing in in the background must not skip the welcome")
        flow.go(to: .signIn)
        flow.signInChanged(true)
        XCTAssertEqual(flow.stage, .ready)
        XCTAssertEqual(AppFlow(defaults: defaults).stage, .ready)
        flow.didSignOut(keeping: nil)
        XCTAssertEqual(flow.stage, .signIn)
        XCTAssertEqual(AppFlow(defaults: defaults).stage, .welcome)
    }
    @MainActor func testAppearancePanelFirstChoiceAndEditing() throws {
        let appearance = AppearanceState()
        XCTAssertFalse(appearance.isShown)
        appearance.beginFirstThemeChoice()
        XCTAssertTrue(appearance.isShown)
        XCTAssertTrue(appearance.isChoosingFirstTheme)
        appearance.themeChosen()
        XCTAssertFalse(appearance.isChoosingFirstTheme)
        appearance.newTheme(from: preset("paper"))
        XCTAssertEqual(appearance.preview?.name, "My Paper", "The draft previews while it's edited")
        XCTAssertEqual(appearance.preview?.isCustom, true)
        appearance.activeThemeChanged(to: "paper")
        XCTAssertNotNil(appearance.edit, "Selecting the theme an edit started from keeps the edit")
        appearance.activeThemeChanged(to: "midnight")
        XCTAssertNil(appearance.edit, "Choosing another theme abandons the edit")
        appearance.customize(preset("clay"))
        appearance.isShown = false
        XCTAssertNil(appearance.preview, "Closing the panel abandons an edit")
        appearance.customize(preset("clay"))
        let draft = try XCTUnwrap(appearance.edit)
        appearance.cancelEdit()
        appearance.updateEdit(draft)
        XCTAssertNil(appearance.edit, "A control finishing after Cancel doesn't bring the edit back")
        let store = ThemeStore(defaults: makeDefaults())
        appearance.customize(preset("clay"))
        appearance.edit?.draft.colors.accent = "112233"
        appearance.saveEdit(to: store)
        XCTAssertNil(appearance.edit)
        XCTAssertEqual(store.selected.colors.accent, "112233", "Saving keeps the draft as the selected theme")
    }
    func testTabTitlesAndSavedAddresses() {
        XCTAssertEqual(NavigationPolicy.pageTitle("The 4P Framework | Notion"), "The 4P Framework")
        XCTAssertEqual(NavigationPolicy.pageTitle("  "), "Notion")
        XCTAssertEqual(NavigationPolicy.withoutQuery(URL(string: "https://app.notion.com/Page-1?pvs=4#abc")!)?.absoluteString, "https://app.notion.com/Page-1")
    }
    @MainActor func testNotionDefaultSelection() {
        let store = ThemeStore(defaults: makeDefaults())
        store.activate(PotionTheme.notionDefault.id)
        XCTAssertFalse(store.enabled)
        XCTAssertEqual(store.activeID, PotionTheme.notionDefault.id)
        store.activate("midnight")
        XCTAssertTrue(store.enabled)
        XCTAssertEqual(store.selected.name, "Midnight")
    }
    @MainActor func testSaveEditDeleteAndRestoreTheme() {
        let defaults = makeDefaults()
        let store = ThemeStore(defaults: defaults)
        var theme = preset("lavender")
        theme.name = "My lavender"
        store.save(theme)
        XCTAssertTrue(store.selected.isCustom)
        XCTAssertNotEqual(store.selected.id, theme.id)
        var edited = store.selected
        edited.colors.accent = "112233"
        store.save(edited)
        XCTAssertEqual(store.customs.count, 1)
        let restored = ThemeStore(defaults: defaults)
        XCTAssertEqual(restored.selected.colors.accent, "112233")
        restored.delete(restored.selected)
        XCTAssertTrue(restored.customs.isEmpty)
        XCTAssertEqual(restored.selected.id, "paper")
    }
    func testAllBundledFontsAndPreviewExist() {
        XCTAssertEqual(FontCatalog.families.count, 35)
        for theme in PotionTheme.presets {
            for family in [theme.fonts.heading, theme.fonts.body] { XCTAssertNotNil(FontCatalog.url(for: family), family) }
        }
        XCTAssertNotNil(Workspace.previewURL)
    }
    func testEveryPresetHasItsOwnColorSetAndFontSet() {
        XCTAssertEqual(PotionTheme.presets.count, 24)
        XCTAssertEqual(Set(PotionTheme.presets.map(\.id)).count, 24)
        XCTAssertEqual(Set(PotionTheme.presets.map(\.colors)).count, 24)
        XCTAssertEqual(PotionTheme.fontSets.count, 24)
        let dark = PotionTheme.presets.filter(\.isDark).count
        XCTAssertEqual(dark, 10, "A good mix of light and dark themes")
    }
    func testPresetsAreComfortableToRead() {
        for theme in PotionTheme.presets {
            let c = theme.colors
            XCTAssertGreaterThanOrEqual(contrast(c.text, c.background), 7, "\(theme.name) text")
            XCTAssertGreaterThanOrEqual(contrast(c.text, c.surface), 7, "\(theme.name) text on surfaces")
            XCTAssertGreaterThanOrEqual(contrast(c.title, c.background), 4.5, "\(theme.name) title")
            XCTAssertGreaterThanOrEqual(contrast(c.heading, c.background), 4.5, "\(theme.name) headings")
            XCTAssertGreaterThanOrEqual(contrast(c.accent, c.background), 4.5, "\(theme.name) links")
            XCTAssertGreaterThanOrEqual(contrast(c.accent, c.surface), 4.5, "\(theme.name) links on surfaces")
            XCTAssertEqual(theme.validated, theme, "\(theme.name) uses only valid colors and bundled fonts")
            let hues = [c.title, c.heading].map { NSColor(hex: $0).hueComponent * 360 }
            let spread = min(abs(hues[0] - hues[1]), 360 - abs(hues[0] - hues[1]))
            // Either two colors, or two clearly different shades of one.
            XCTAssertTrue(spread >= 30 || contrast(c.title, c.heading) >= 1.3, "\(theme.name) sets its headings apart from its title")
        }
    }
    @MainActor func testWebKitLiveThemeAndRemoval() async throws {
        let workspace = Workspace()
        let paper = preset("paper")
        workspace.apply(paper)
        await loadPreview(workspace)
        func js(_ source: String) async throws -> Any? { try await self.js(source, in: workspace) }
        /// A computed style of the first element matching a selector.
        func style(_ property: String, _ selector: String) async throws -> String? {
            try await js("getComputedStyle(document.querySelector('\(selector)')).\(property)") as? String
        }
        func color(_ selector: String) async throws -> String? { try await style("color", selector) }
        /// The families of the page's loaded fonts, sorted and comma-separated.
        func fontFamilies() async throws -> String? {
            try await js("[...new Set([...document.fonts].map(font => font.family.replace(/[\"']/g, '')))].sort().join(',')") as? String
        }
        let background = try await style("backgroundColor", "body")
        XCTAssertEqual(background, "rgb(248, 245, 239)")
        let fonts = try await fontFamilies()
        XCTAssertEqual(fonts, "DM Sans,Lora", "Pages load only the theme's own fonts")
        let heading = try await style("fontFamily", "h1")
        XCTAssertTrue(heading?.contains("Lora") == true)
        let title = try await color("h1")
        let subheading = try await color("h2")
        let text = try await color(".intro")
        XCTAssertEqual(title, "rgb(75, 103, 42)")
        XCTAssertEqual(subheading, "rgb(154, 74, 44)")
        XCTAssertEqual(text, "rgb(58, 62, 54)")
        let midnight = preset("midnight")
        workspace.apply(midnight)
        let dark = try await style("backgroundColor", "body")
        XCTAssertEqual(dark, "rgb(31, 36, 43)")
        let switchedFonts = try await fontFamilies()
        XCTAssertEqual(switchedFonts, "DM Sans,Space Grotesk", "Changing themes swaps the embedded fonts")
        workspace.apply(nil)
        let disabled = try await js("document.getElementById('potion-theme').textContent") as? String
        XCTAssertEqual(disabled, "")
        workspace.apply(preset("botanical"))
        _ = try await js("document.getElementById('potion-theme').remove()")
        let reapplied = try await style("backgroundColor", "body")
        XCTAssertEqual(reapplied, "rgb(238, 242, 236)")
        _ = try await js("""
          document.body.insertAdjacentHTML('beforeend', `<div class="notion-app-inner notion-dark-theme">
          <main class="notion-frame" id="test-frame" style="background: var(--c-bacPri)">
          <div class="notion-page-block"><h1 id="test-title" contenteditable="false" style="color:var(--c-texPri)">Title</h1></div>
          <div class="notion-page-content" id="test-content">
            <div class="notion-header-block"><div id="test-heading" contenteditable="false" style="font-size: 30px; color: rgb(55, 53, 47);">Heading</div></div>
            <div class="notion-sub_header-block"><div id="test-colored-heading" contenteditable="true" style="color:rgb(0,0,255)">Blue heading</div></div>
            <div class="notion-page-block"><div id="test-page-link">Linked page</div></div>
            <div class="notion-text-block"><div id="test-body" contenteditable="true" style="font-size:16px;color:var(--c-texPri)">Body</div></div>
            <div id="test-colored" style="color:rgb(255,0,0)">Intentional red</div>
            <code id="test-code">code</code>
          </div></main><div class="notion-sidebar-container"><div class="notion-sidebar">
            <div id="test-sidebar-list" class="notion-scroller vertical">Pages</div>
            <div class="notion-page-block"><div id="test-sidebar-page" contenteditable="false">Sidebar page</div></div>
          </div></div></div>`);
        """)
        let expectations: [(property: String, id: String, value: String, message: String)] = [
            ("backgroundColor", "test-frame", "rgb(238, 242, 236)", "The page frame paints the page color"),
            ("backgroundColor", "test-content", "rgba(0, 0, 0, 0)", "The text column shows the page behind it rather than painting its own copy"),
            ("fontSize", "test-heading", "30px", "Heading hierarchy must not be flattened by body sizing"),
            ("color", "test-body", "rgb(46, 59, 52)", "Body text has the theme's text color"),
            ("color", "test-title", "rgb(30, 106, 78)", "The page title has the theme's title color"),
            ("color", "test-heading", "rgb(140, 58, 94)", "Headings in Notion's default color take the theme's heading color"),
            ("color", "test-colored-heading", "rgb(0, 0, 255)", "A color chosen for a heading stays"),
            ("color", "test-page-link", "rgb(46, 59, 52)", "Links to pages inside a page aren't styled as its title"),
            ("color", "test-colored", "rgb(255, 0, 0)", "Colors people choose stay"),
            ("color", "test-sidebar-page", "rgb(46, 59, 52)", "Pages listed in the sidebar aren't styled as the page title"),
            ("backgroundColor", "test-sidebar-list", "rgba(0, 0, 0, 0)", "The sidebar's page list shows the sidebar color, not the page color"),
        ]
        for check in expectations {
            let value = try await style(check.property, "#" + check.id)
            XCTAssertEqual(value, check.value, check.message)
        }
        let titleFont = try await style("fontFamily", "#test-title")
        XCTAssertTrue(titleFont?.contains("DM Serif Display") == true, "Read-only pages, like trashed ones, still get the theme's heading font")
        let codeFont = try await style("fontFamily", "#test-code")
        XCTAssertTrue(codeFont?.contains("monospace") == true)
    }
    @MainActor func testPageAndSidebarHideScrollBars() async throws {
        let workspace = Workspace()
        workspace.usesWindowLayout = true
        await loadPreview(workspace)
        // Notion styles its scroll bars, which keeps them visible; the layout hides the page's and sidebar's.
        let widths = try await js("""
          document.head.insertAdjacentHTML('beforeend', '<style>::-webkit-scrollbar { width: 10px; height: 10px; background: gray; }</style>');
          document.body.insertAdjacentHTML('beforeend', `
            <div class="notion-frame"><div id="page" class="notion-scroller vertical" style="height:100px;overflow:auto"><div style="height:500px"></div></div>
              <div id="table" class="notion-scroller horizontal" style="width:100px;height:100px;overflow:auto"><div style="width:500px;height:500px"></div></div></div>
            <div class="notion-sidebar"><div id="sidebar" class="notion-scroller vertical" style="height:100px;overflow:auto"><div style="height:500px"></div></div></div>`);
          ['page', 'sidebar', 'table'].map(id => {
            const el = document.getElementById(id);
            return el.offsetWidth - el.clientWidth;
          });
        """, in: workspace) as? [Int]
        XCTAssertEqual(widths, [0, 0, 10], "Page and sidebar scroll bars are hidden; a wide table's stays")
        workspace.usesWindowLayout = false
        let layout = try await js("document.getElementById('potion-layout').textContent", in: workspace) as? String
        XCTAssertEqual(layout, "", "Leaving the workspace layout reaches the open page without a reload")
    }
    @MainActor func testThemeSetsNotionsModeAndRestoresItsOwn() async throws {
        let workspace = Workspace()
        workspace.apply(preset("paper"))
        await loadPreview(workspace)
        /// Whether the body and Notion's app container are marked dark, as "body,app".
        func mode() async throws -> String? {
            try await js("""
              [document.body, document.getElementById('app')].map(node => node.classList.contains('notion-dark-theme') && !node.classList.contains('notion-light-theme')).join(',') + (document.body.classList.contains('dark') ? ',dark' : '')
            """, in: workspace) as? String
        }
        // Notion with its appearance set to Dark.
        _ = try await js("""
          localStorage.setItem('theme', '{"mode":"dark"}');
          document.body.className = 'notion-body dark notion-dark-theme';
          document.body.insertAdjacentHTML('beforeend', '<div id="app" class="notion-app-inner notion-dark-theme"></div>');
        """, in: workspace)
        let themed = try await mode()
        XCTAssertEqual(themed, "false,false", "A light theme shows Notion's light mode, so its controls are drawn for a light page")
        _ = try await js("document.body.className = 'notion-body dark notion-dark-theme'", in: workspace)
        let reapplied = try await mode()
        XCTAssertEqual(reapplied, "false,false", "Notion setting its own mode again doesn't override the theme")
        workspace.apply(nil)
        let restored = try await mode()
        XCTAssertEqual(restored, "true,true,dark", "Notion's own look goes back to its appearance setting")
    }
    @MainActor func testFontsLoadOnlyWhileThemed() async throws {
        let workspace = Workspace()
        workspace.apply(nil)
        await loadPreview(workspace)
        let unthemed = try await js("document.fonts.size", in: workspace) as? Int
        XCTAssertEqual(unthemed, 0, "Notion's own look doesn't load the bundled fonts")
        workspace.apply(preset("harbor"))
        let themed = try await js("document.fonts.size", in: workspace) as? Int
        XCTAssertEqual(themed, 1, "Turning a theme on brings its fonts to the open page, one family here")
    }
}
