import XCTest
import WebKit
@testable import Potion

final class PotionTests: XCTestCase {
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
    @MainActor func testSaveEditDeleteAndRestoreTheme() {
        let suite = "PotionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
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
        XCTAssertNotNil(Bundle.main.url(forResource: "Preview", withExtension: "html"))
    }
    @MainActor func testWebKitLiveThemeAndRemoval() async throws {
        let workspace = Workspace()
        workspace.apply(PotionTheme.presets[0], enabled: true)
        workspace.showPreview()
        let loaded = NSPredicate { _, _ in workspace.webView.url?.isFileURL == true && !workspace.webView.isLoading }
        let expectation = XCTNSPredicateExpectation(predicate: loaded, object: nil)
        await fulfillment(of: [expectation], timeout: 15)
        let paper = try await workspace.webView.evaluateJavaScript("getComputedStyle(document.body).backgroundColor") as? String
        XCTAssertEqual(paper, "rgb(248, 245, 239)")
        let fontLoaded = try await workspace.webView.evaluateJavaScript("document.fonts.size") as? Int
        XCTAssertEqual(fontLoaded, 6)
        let heading = try await workspace.webView.evaluateJavaScript("getComputedStyle(document.querySelector('h1')).fontFamily") as? String
        XCTAssertTrue(heading?.contains("Lora") == true)
        workspace.apply(PotionTheme.presets[4], enabled: true)
        let dark = try await workspace.webView.evaluateJavaScript("getComputedStyle(document.body).backgroundColor") as? String
        XCTAssertEqual(dark, "rgb(32, 37, 44)")
        workspace.apply(PotionTheme.presets[4], enabled: false)
        let disabled = try await workspace.webView.evaluateJavaScript("document.getElementById('potion-theme').textContent") as? String
        XCTAssertEqual(disabled, "")
        workspace.apply(PotionTheme.presets[1], enabled: true)
        _ = try await workspace.webView.evaluateJavaScript("document.getElementById('potion-theme').remove()")
        let reapplied = try await workspace.webView.evaluateJavaScript("getComputedStyle(document.body).backgroundColor") as? String
        XCTAssertEqual(reapplied, "rgb(237, 242, 235)")
        _ = try await workspace.webView.evaluateJavaScript("""
          document.body.insertAdjacentHTML('beforeend', `<div class="notion-app-inner notion-dark-theme"><div class="notion-page-content">
            <div class="notion-header-block"><div id="test-heading" contenteditable="true" style="font-size:30px">Heading</div></div>
            <div class="notion-text-block"><div id="test-body" contenteditable="true" style="font-size:16px;color:var(--c-texPri)">Body</div></div>
            <div id="test-colored" style="color:rgb(255,0,0)">Intentional red</div>
            <code id="test-code">code</code>
          </div></div>`);
        """)
        let headingSize = try await workspace.webView.evaluateJavaScript("getComputedStyle(document.getElementById('test-heading')).fontSize") as? String
        XCTAssertEqual(headingSize, "30px", "Heading hierarchy must not be flattened by body sizing")
        let bodyColor = try await workspace.webView.evaluateJavaScript("getComputedStyle(document.getElementById('test-body')).color") as? String
        XCTAssertEqual(bodyColor, "rgb(41, 63, 53)")
        let intentionalColor = try await workspace.webView.evaluateJavaScript("getComputedStyle(document.getElementById('test-colored')).color") as? String
        XCTAssertEqual(intentionalColor, "rgb(255, 0, 0)")
        let codeFont = try await workspace.webView.evaluateJavaScript("getComputedStyle(document.getElementById('test-code')).fontFamily") as? String
        XCTAssertTrue(codeFont?.contains("monospace") == true)
    }
}
