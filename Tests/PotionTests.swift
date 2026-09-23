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
    func testPaletteValidationRejectsCSSAndClampsType() {
        var theme = PotionTheme.presets[0]
        theme.background = "red; } body {display:none}"
        theme.accent = "#abc123"
        theme.headingFont = "fake'; url(evil)"
        theme.fontSize = 500
        theme.lineHeight = 0
        let result = theme.validated
        XCTAssertEqual(result.background, "F8F5EF")
        XCTAssertEqual(result.accent, "ABC123")
        XCTAssertEqual(result.headingFont, "Lora")
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
    @MainActor func testAppearancePanelFirstChoiceAndEditing() {
        let appearance = AppearanceState()
        XCTAssertFalse(appearance.isShown)
        appearance.beginFirstThemeChoice()
        XCTAssertTrue(appearance.isShown)
        XCTAssertTrue(appearance.isChoosingFirstTheme)
        appearance.themeChosen()
        XCTAssertFalse(appearance.isChoosingFirstTheme)
        appearance.newTheme(from: PotionTheme.presets[0])
        XCTAssertEqual(appearance.editing?.name, "My Paper")
        XCTAssertEqual(appearance.editing?.isCustom, true)
        appearance.preview = appearance.editing
        appearance.isShown = false
        XCTAssertNil(appearance.editing, "Closing the panel abandons an edit")
        XCTAssertNil(appearance.preview, "Ending an edit stops previewing it")
    }
    func testTabTitlesAndSavedAddresses() {
        XCTAssertEqual(NavigationPolicy.pageTitle("The 4P Framework | Notion"), "The 4P Framework")
        XCTAssertEqual(NavigationPolicy.pageTitle("  "), "Notion")
        XCTAssertEqual(NavigationPolicy.withoutQuery(URL(string: "https://app.notion.com/Page-1?pvs=4#abc")!)?.absoluteString, "https://app.notion.com/Page-1")
    }
    @MainActor func testOriginalNotionSelection() {
        let defaults = makeDefaults()
        let store = ThemeStore(defaults: defaults)
        store.activate(ThemeStore.originalID)
        XCTAssertFalse(store.enabled)
        XCTAssertEqual(store.activeID, ThemeStore.originalID)
        store.activate("midnight")
        XCTAssertTrue(store.enabled)
        XCTAssertEqual(store.selected.name, "Midnight")
    }
    @MainActor func testSaveEditDeleteAndRestoreTheme() {
        let defaults = makeDefaults()
        let store = ThemeStore(defaults: defaults)
        var theme = PotionTheme.presets[2]
        theme.name = "My lavender"
        store.save(theme)
        XCTAssertTrue(store.selected.isCustom)
        XCTAssertNotEqual(store.selected.id, theme.id)
        var edited = store.selected
        edited.accent = "112233"
        store.save(edited)
        XCTAssertEqual(store.customs.count, 1)
        let restored = ThemeStore(defaults: defaults)
        XCTAssertEqual(restored.selected.accent, "112233")
        restored.delete(restored.selected)
        XCTAssertTrue(restored.customs.isEmpty)
        XCTAssertEqual(restored.selected.id, "paper")
    }
    func testAllBundledFontsAndPreviewExist() {
        for family in FontCatalog.families { XCTAssertNotNil(FontCatalog.url(for: family), family) }
        XCTAssertNotNil(Workspace.previewURL)
    }
    @MainActor func testWebKitLiveThemeAndRemoval() async throws {
        let workspace = Workspace()
        workspace.apply(PotionTheme.presets[0], enabled: true)
        workspace.showPreview()
        let loaded = NSPredicate { _, _ in workspace.webView.url?.isFileURL == true && !workspace.webView.isLoading }
        let expectation = XCTNSPredicateExpectation(predicate: loaded, object: nil)
        await fulfillment(of: [expectation], timeout: 15)
        func js(_ source: String) async throws -> Any? { try await workspace.webView.evaluateJavaScript(source) }
        let paper = try await js("getComputedStyle(document.body).backgroundColor") as? String
        XCTAssertEqual(paper, "rgb(248, 245, 239)")
        let fontLoaded = try await js("document.fonts.size") as? Int
        XCTAssertEqual(fontLoaded, 6)
        let heading = try await js("getComputedStyle(document.querySelector('h1')).fontFamily") as? String
        XCTAssertTrue(heading?.contains("Lora") == true)
        workspace.apply(PotionTheme.presets[4], enabled: true)
        let dark = try await js("getComputedStyle(document.body).backgroundColor") as? String
        XCTAssertEqual(dark, "rgb(32, 37, 44)")
        workspace.apply(PotionTheme.presets[4], enabled: false)
        let disabled = try await js("document.getElementById('potion-theme').textContent") as? String
        XCTAssertEqual(disabled, "")
        workspace.apply(PotionTheme.presets[1], enabled: true)
        _ = try await js("document.getElementById('potion-theme').remove()")
        let reapplied = try await js("getComputedStyle(document.body).backgroundColor") as? String
        XCTAssertEqual(reapplied, "rgb(237, 242, 235)")
        _ = try await js("""
          document.body.insertAdjacentHTML('beforeend', `<div class="notion-app-inner notion-dark-theme"><div class="notion-page-content">
            <div class="notion-header-block"><div id="test-heading" contenteditable="true" style="font-size:30px">Heading</div></div>
            <div class="notion-text-block"><div id="test-body" contenteditable="true" style="font-size:16px;color:var(--c-texPri)">Body</div></div>
            <div id="test-colored" style="color:rgb(255,0,0)">Intentional red</div>
            <code id="test-code">code</code>
          </div><div class="notion-sidebar-container"><div class="notion-sidebar">
            <div id="test-sidebar-list" class="notion-scroller vertical">Pages</div>
          </div></div></div>`);
        """)
        let headingSize = try await js("getComputedStyle(document.getElementById('test-heading')).fontSize") as? String
        XCTAssertEqual(headingSize, "30px", "Heading hierarchy must not be flattened by body sizing")
        let bodyColor = try await js("getComputedStyle(document.getElementById('test-body')).color") as? String
        XCTAssertEqual(bodyColor, "rgb(41, 63, 53)")
        let intentionalColor = try await js("getComputedStyle(document.getElementById('test-colored')).color") as? String
        XCTAssertEqual(intentionalColor, "rgb(255, 0, 0)")
        let sidebarList = try await js("getComputedStyle(document.getElementById('test-sidebar-list')).backgroundColor") as? String
        XCTAssertEqual(sidebarList, "rgba(0, 0, 0, 0)", "The sidebar's page list shows the sidebar color, not the page color")
        let codeFont = try await js("getComputedStyle(document.getElementById('test-code')).fontFamily") as? String
        XCTAssertTrue(codeFont?.contains("monospace") == true)
    }
    @MainActor func testFontsLoadOnlyWhileThemed() async throws {
        let workspace = Workspace()
        workspace.apply(PotionTheme.presets[0], enabled: false)
        workspace.showPreview()
        let loaded = NSPredicate { _, _ in workspace.webView.url?.isFileURL == true && !workspace.webView.isLoading }
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: loaded, object: nil)], timeout: 15)
        let unthemed = try await workspace.webView.evaluateJavaScript("document.fonts.size") as? Int
        XCTAssertEqual(unthemed, 0, "Notion's own look doesn't load the bundled fonts")
        workspace.apply(PotionTheme.presets[0], enabled: true)
        let themed = try await workspace.webView.evaluateJavaScript("document.fonts.size") as? Int
        XCTAssertEqual(themed, 6, "Turning a theme on brings the fonts to the open page")
    }
}
