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

enum NavigationPolicy {
    static let notionDomains = ["notion.so", "notion.site", "notion.com"]
    static func isNotion(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return notionDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
    static func isAuthentication(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return ["accounts.google.com", "appleid.apple.com", "login.microsoftonline.com"].contains(host)
    }
    static func canOpenExternally(_ url: URL) -> Bool { ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") }
}
