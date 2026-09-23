import Foundation

enum ThemeInjection {
    private static let fontCSS: String = FontCatalog.families.compactMap { family in
        guard let url = FontCatalog.url(for: family), let data = try? Data(contentsOf: url) else { return nil }
        return "@font-face { font-family: '\(family)'; src: url(data:font/ttf;base64,\(data.base64EncodedString())) format('truetype'); font-weight: 100 900; font-display: swap; }"
    }.joined(separator: "\n")

    static func css(for input: PotionTheme) -> String {
        let t = input.validated
        return """
        :root { --potion-bg: #\(t.background); --potion-surface: #\(t.surface); --potion-text: #\(t.text); --potion-accent: #\(t.accent); color-scheme: \(t.isDark ? "dark" : "light"); }
        :root, .notion-light-theme, .notion-dark-theme, .notion-app-inner {
          --c-bacPri: #\(t.background) !important; --c-bacSec: #\(t.surface) !important; --c-bacTer: #\(t.surface) !important;
          --c-bacEle: #\(t.background) !important; --c-popBac: #\(t.background) !important;
          --c-texPri: #\(t.text) !important; --c-texSec: #\(t.text)B3 !important; --c-texTer: #\(t.text)8C !important;
          --c-icoPri: #\(t.text) !important; --c-icoSec: #\(t.text)99 !important;
          --c-borPri: #\(t.text)20 !important; --c-borSec: #\(t.text)14 !important;
          --c-bluTexAccPri: #\(t.accent) !important; --ca-staHov: #\(t.accent)14 !important;
        }
        body, .notion-app-inner { background: var(--potion-bg) !important; color: var(--potion-text) !important; }
        .notion-app-inner, .notion-page-content, .potion-preview { font-family: '\(t.bodyFont)', sans-serif !important; }
        .notion-frame, .notion-scroller.vertical, .notion-page-content, .notion-topbar { background-color: var(--potion-bg) !important; }
        .notion-sidebar-container, .notion-sidebar { background-color: var(--potion-surface) !important; }
        .notion-page-content { font-size: \(t.fontSize)px !important; line-height: \(t.lineHeight) !important; }
        .notion-text-block [contenteditable=true], .notion-bulleted_list-block [contenteditable=true], .notion-numbered_list-block [contenteditable=true], .notion-to_do-block [contenteditable=true] { font-size: \(t.fontSize)px !important; line-height: \(t.lineHeight) !important; }
        .notion-page-block [contenteditable=true], .notion-header-block [contenteditable=true], .notion-sub_header-block [contenteditable=true], .notion-sub_sub_header-block [contenteditable=true], .potion-preview h1, .potion-preview h2, .potion-preview h3 { font-family: '\(t.headingFont)', serif !important; }
        .notion-page-content a, .potion-preview a { color: var(--potion-accent) !important; }
        .notion-app-inner { color: var(--potion-text) !important; }
        .notion-page-content [style*="color: rgb(55, 53, 47)"], .notion-page-content [style*="color: rgba(255, 255, 255, 0.81)"] { color: var(--potion-text) !important; }
        .notion-code-block, .notion-code-block *, code, pre { font-family: ui-monospace, SFMono-Regular, monospace !important; }
        ::selection { background: #\(t.accent)40; }
        .potion-preview { font-size: \(t.fontSize)px; line-height: \(t.lineHeight); }
        """
    }

    static func script(theme: PotionTheme, enabled: Bool, includeFonts: Bool) -> String {
        let css = enabled ? css(for: theme) : ""
        let payload: [String: String] = ["css": css, "fonts": includeFonts ? fontCSS : ""]
        let json = String(data: try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), encoding: .utf8)!
        return """
        (() => {
          const domains = \(String(data: try! JSONEncoder().encode(NavigationPolicy.notionDomains), encoding: .utf8)!);
          if (!(location.protocol === 'file:' || (location.protocol === 'https:' && domains.some(domain => location.hostname === domain || location.hostname.endsWith('.' + domain))))) return;
          const payload = \(json);
          if (payload.fonts) window.__potionFonts = payload.fonts;
          const apply = () => {
            if (!document.documentElement) return;
            const put = (id, css) => {
              let node = document.getElementById(id);
              if (!node) { node = document.createElement('style'); node.id = id; (document.head || document.documentElement).appendChild(node); }
              if (node.textContent !== css) node.textContent = css;
            };
            if (window.__potionFonts) put('potion-fonts', window.__potionFonts);
            put('potion-theme', payload.css);
          };
          window.__potionApply = apply;
          apply();
          if (!window.__potionObserver) {
            window.__potionObserver = new MutationObserver(() => {
              if (!document.getElementById('potion-theme') || !document.getElementById('potion-fonts')) window.__potionApply();
            });
            window.__potionObserver.observe(document.documentElement, {childList: true, subtree: true});
          }
        })();
        """
    }
}

extension ThemeInjection {
    static let chromeMessage = "potionChrome"

    /// Reports the width and colors of Notion's sidebar and page, so the native header can continue them.
    static let chromeScript = """
    (() => {
      if (window.__potionChromePost || !window.webkit?.messageHandlers?.\(chromeMessage)) return;
      const opaque = (element) => {
        for (let node = element; node && node !== document.documentElement; node = node.parentElement) {
          const color = getComputedStyle(node).backgroundColor;
          if (color && color !== 'transparent' && !/,\\s*0(\\.0+)?\\)$/.test(color)) return color;
        }
        return getComputedStyle(document.body || document.documentElement).backgroundColor;
      };
      let last = '';
      let observed = null;
      const resize = new ResizeObserver(() => post());
      const post = () => {
        if (!document.body) return;
        const container = document.querySelector('.notion-sidebar-container');
        if (container !== observed) { if (observed) resize.unobserve(observed); if (container) resize.observe(container); observed = container; }
        let width = 0;
        if (container) {
          const box = container.getBoundingClientRect();
          if (box.left <= 1 && box.width > 40 && getComputedStyle(container).visibility !== 'hidden') width = Math.round(box.right);
        }
        const sidebar = container && (container.querySelector('.notion-sidebar') || container);
        const page = document.querySelector('.notion-frame') || document.querySelector('.notion-app-inner') || document.body;
        const message = { sidebarWidth: width, sidebarColor: sidebar ? opaque(sidebar) : '', pageColor: opaque(page) };
        const key = JSON.stringify(message);
        if (key !== last) { last = key; window.webkit.messageHandlers.\(chromeMessage).postMessage(message); }
      };
      window.__potionChromePost = post;
      window.addEventListener('resize', post);
      setInterval(post, 400);
      post();
    })();
    """
    static let chromeRefresh = "\n;window.__potionChromePost && requestAnimationFrame(() => window.__potionChromePost());"

    /// Sends Notion the same key event as its ⌘\ shortcut, which shows or hides its sidebar.
    static let toggleSidebarScript = """
    (() => {
      const event = { key: '\\\\', code: 'Backslash', keyCode: 220, which: 220, metaKey: true, bubbles: true, cancelable: true };
      (document.activeElement || document.body).dispatchEvent(new KeyboardEvent('keydown', event));
      (document.activeElement || document.body).dispatchEvent(new KeyboardEvent('keyup', event));
    })();
    """
}

enum NavigationDecision: Equatable { case allow, openExternally, cancel }

enum NavigationPolicy {
    static let notionDomains = ["notion.so", "notion.site", "notion.com"]
    static let authenticationHosts: Set<String> = [
        "accounts.google.com", "appleid.apple.com", "idmsa.apple.com",
        "login.microsoftonline.com", "login.microsoft.com", "login.live.com", "account.live.com",
    ]
    /// First path components of Notion pages that exist before or during sign-in.
    private static let signInPaths: Set<String> = ["", "login", "signup", "logout", "onboarding", "sso", "loginwithemail", "verifynopopupblockerhtmlandredirect"]

    static func isNotion(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return notionDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
    static func isAuthentication(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return authenticationHosts.contains(host)
    }
    /// A Notion page title without the “| Notion” suffix, for window tabs.
    static func pageTitle(_ title: String) -> String {
        var result = title.trimmingCharacters(in: .whitespaces)
        for suffix in [" | Notion", " – Notion", " - Notion"] where result.hasSuffix(suffix) { result.removeLast(suffix.count) }
        return result.isEmpty ? "Notion" : result
    }
    static func withoutQuery(_ url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }
    static func canOpenExternally(_ url: URL) -> Bool { ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") }

    /// True for pages of a signed-in workspace, which is how Potion knows sign-in has finished.
    static func isWorkspacePage(_ url: URL) -> Bool {
        guard isNotion(url), let host = url.host?.lowercased(), !host.hasSuffix("notion.site"), host != "identity.notion.com" else { return false }
        let first = url.pathComponents.dropFirst().first?.lowercased() ?? ""
        return !signInPaths.contains(first) && !first.contains("popup") && !first.contains("callback")
    }
    /// Notion opens OAuth sign-in through a sized popup on its own domain, which must stay a real window.
    static func isSignInPopup(_ url: URL, hasWindowSize: Bool) -> Bool {
        let path = url.path.lowercased()
        return hasWindowSize || path.contains("popup")
    }

    /// Main-window navigations. Notion and sign-in pages load in place; links people click to other sites open
    /// in their browser. Redirects away from Notion (enterprise SSO) stay in place so sign-in can complete.
    static func decision(for url: URL, isLinkClick: Bool, from current: URL?) -> NavigationDecision {
        if url.absoluteString == "about:blank" || isNotion(url) || isAuthentication(url) { return .allow }
        guard url.scheme?.lowercased() == "https" else { return canOpenExternally(url) ? .openExternally : .cancel }
        let leavingNotion = current.map(isNotion) ?? true
        return isLinkClick && leavingNotion ? .openExternally : .allow
    }
    /// Sign-in popup navigations. The first page must belong to Notion or a known identity provider; after that the
    /// provider may redirect wherever its sign-in flow needs to go.
    static func popupDecision(for url: URL, from current: URL?) -> NavigationDecision {
        if url.absoluteString == "about:blank" || isNotion(url) || isAuthentication(url) { return .allow }
        let started = current.map { $0.absoluteString != "about:blank" } ?? false
        if started && url.scheme?.lowercased() == "https" { return .allow }
        return canOpenExternally(url) ? .openExternally : .cancel
    }
}
