import Foundation

enum ThemeInjection {
    /// Encodes a value as a JavaScript literal, for embedding in injected scripts.
    private static func jsLiteral<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        // Slashes are common in the embedded fonts' base64 and need no escaping.
        encoder.outputFormatting = .withoutEscapingSlashes
        return String(data: try! encoder.encode(value), encoding: .utf8)!
    }

    /// Runs the rest of an injected script only on Notion's pages and the offline preview.
    private static let themedPagesOnly = """
      const domains = \(jsLiteral(NavigationPolicy.notionDomains));
      if (!(location.protocol === 'file:' || (location.protocol === 'https:' && domains.some(domain => location.hostname === domain || location.hostname.endsWith('.' + domain))))) return;
    """

    /// Creates or updates one of Potion's style elements, leaving it alone when the CSS is unchanged.
    private static let putStyle = """
      const put = (id, css) => {
        let node = document.getElementById(id);
        if (!node) { node = document.createElement('style'); node.id = id; (document.head || document.documentElement).appendChild(node); }
        if (node.textContent !== css) node.textContent = css;
      };
    """

    /// The last fonts script built, shared by every tab since they all show the same theme.
    @MainActor private static var fontCache: (fonts: ThemeFonts, script: String)?

    /// Each family's embedded @font-face rule, read and encoded the first time a theme uses it.
    @MainActor private static var fontFaces: [String: String] = [:]
    @MainActor private static func fontFace(_ family: String) -> String? {
        if let rule = fontFaces[family] { return rule }
        guard let url = FontCatalog.url(for: family), let data = try? Data(contentsOf: url) else { return nil }
        let rule = "@font-face { font-family: '\(family)'; src: url(data:font/ttf;base64,\(data.base64EncodedString())) format('truetype'); font-weight: 100 900; font-display: swap; }"
        fontFaces[family] = rule
        return rule
    }

    /// A theme's two font families, embedded in the page as their own style element. Installed as its own user script
    /// and resent only when the fonts change, so color and size edits never re-encode or re-compare them.
    @MainActor static func fontScript(for fonts: ThemeFonts) -> String {
        if let fontCache, fontCache.fonts == fonts { return fontCache.script }
        let css = Set([fonts.heading, fonts.body]).sorted().compactMap(fontFace).joined(separator: "\n")
        let script = """
        (() => {
        \(themedPagesOnly)
          window.__potionFonts = \(jsLiteral(css));
        \(putStyle)
          if (document.documentElement) put('potion-fonts', window.__potionFonts);
        })();
        """
        fontCache = (fonts, script)
        return script
    }

    /// Notion's page title. Links to other pages, inside a page or in the sidebar, use the same class.
    private static let pageTitle = ".notion-page-block:not(.notion-page-content *, .notion-sidebar *)"
    private static let headingBlocks = ".notion-header-block, .notion-sub_header-block, .notion-sub_sub_header-block"

    static func css(for input: PotionTheme) -> String {
        let t = input.validated
        let c = t.colors
        // Page colors are written out rather than read from variables, and only the page's outer layers paint them:
        // the text column stays transparent, so it can never show a different shade than the page around it.
        // Fonts match text whether or not it's editable, since Notion makes trashed and shared pages read-only.
        // Title and heading blocks set their own text color, both directly and through Notion's text variable, which
        // also recolors text Notion marks with its default color. Block colors people choose stay as they are.
        return """
        :root { --potion-bg: #\(c.background); --potion-surface: #\(c.surface); --potion-text: #\(c.text); --potion-accent: #\(c.accent); color-scheme: \(t.isDark ? "dark" : "light"); }
        :root, .notion-light-theme, .notion-dark-theme, .notion-app-inner {
          --c-bacPri: #\(c.background) !important; --c-bacSec: #\(c.surface) !important; --c-bacTer: #\(c.surface) !important;
          --c-bacEle: #\(c.background) !important; --c-popBac: #\(c.background) !important;
          --c-texPri: #\(c.text) !important; --c-texSec: #\(c.text)B3 !important; --c-texTer: #\(c.text)8C !important;
          --c-icoPri: #\(c.text) !important; --c-icoSec: #\(c.text)99 !important;
          --c-borPri: #\(c.text)20 !important; --c-borSec: #\(c.text)14 !important;
          --c-bluTexAccPri: #\(c.accent) !important; --ca-staHov: #\(c.accent)14 !important;
        }
        body, .notion-app-inner { background: #\(c.background) !important; color: #\(c.text) !important; }
        \(pageTitle), .potion-preview h1 { --c-texPri: #\(c.title) !important; color: #\(c.title); }
        \(headingBlocks), .potion-preview h2, .potion-preview h3 { --c-texPri: #\(c.heading) !important; color: #\(c.heading); }
        .notion-app-inner, .notion-page-content, .potion-preview { font-family: '\(t.fonts.body)', sans-serif !important; }
        .notion-cursor-listener, .notion-frame, .notion-scroller.vertical, .notion-topbar { background-color: #\(c.background) !important; }
        .notion-page-content { background-color: transparent !important; }
        .notion-sidebar-container, .notion-sidebar { background-color: #\(c.surface) !important; }
        .notion-sidebar-container .notion-scroller.vertical { background-color: transparent !important; }
        .notion-page-content, .notion-text-block [contenteditable], .notion-bulleted_list-block [contenteditable], .notion-numbered_list-block [contenteditable], .notion-to_do-block [contenteditable] { font-size: \(t.fontSize)px !important; line-height: \(t.lineHeight) !important; }
        :is(\(pageTitle), \(headingBlocks)) [contenteditable], .potion-preview h1, .potion-preview h2, .potion-preview h3 { font-family: '\(t.fonts.heading)', serif !important; }
        .notion-page-content a, .potion-preview a { color: var(--potion-accent) !important; }
        :is(.notion-page-content, \(pageTitle)) :is([style*="color: rgb(55, 53, 47)"], [style*="color: rgba(255, 255, 255, 0.81)"]) { color: var(--c-texPri) !important; }
        .notion-code-block, .notion-code-block *, code, pre { font-family: ui-monospace, SFMono-Regular, monospace !important; }
        ::selection { background: #\(c.accent)40; }
        .potion-preview { font-size: \(t.fontSize)px; line-height: \(t.lineHeight); }
        """
    }

    static func script(for theme: PotionTheme?) -> String {
        """
        (() => {
        \(themedPagesOnly)
          const css = \(jsLiteral(theme.map(css(for:)) ?? ""));
        \(putStyle)
          const apply = () => {
            if (!document.documentElement) return;
            if (window.__potionFonts && !document.getElementById('potion-fonts')) put('potion-fonts', window.__potionFonts);
            put('potion-theme', css);
          };
          window.__potionApply = apply;
          apply();
          if (!window.__potionObserver) {
            window.__potionObserver = new MutationObserver(() => {
              if (!document.getElementById('potion-theme') || (window.__potionFonts && !document.getElementById('potion-fonts'))) window.__potionApply();
            });
            window.__potionObserver.observe(document.documentElement, {childList: true, subtree: true});
          }
        })();
        """
    }
}

extension ThemeInjection {
    static let chromeMessage = "potionChrome"

    /// Height of the title bar row, shared by Notion's sidebar row and Potion's tab row.
    static let headerHeight: CGFloat = 40

    /// Where the sidebar button sits after the traffic lights, as in Notion's app, open or collapsed.
    static let sidebarButtonX: CGFloat = 88

    /// Lays Notion out like its Mac app: the sidebar's top row moves into the title bar, its collapse button just after
    /// the traffic lights and its inbox and new-page buttons at the right; the page column moves down to make room for
    /// Potion's back, forward and tab row. The elements are tagged by `chromeScript`. The page and sidebar scroll
    /// without visible scroll bars; wide tables and code blocks keep theirs.
    private static let layoutCSS = """
    .potion-sidebar-row { height: \(Int(headerHeight))px !important; padding-inline-start: \(Int(sidebarButtonX))px !important; }
    .potion-page-column { padding-top: \(Int(headerHeight))px !important; }
    .potion-below-header { top: \(Int(headerHeight))px !important; height: calc(100% - \(Int(headerHeight))px) !important; max-height: calc(100% - \(Int(headerHeight))px) !important; }
    .notion-frame .notion-scroller.vertical, .notion-sidebar .notion-scroller.vertical { scrollbar-width: none !important; }
    .notion-frame .notion-scroller.vertical::-webkit-scrollbar, .notion-sidebar .notion-scroller.vertical::-webkit-scrollbar { display: none !important; width: 0 !important; }
    """

    static func layoutFlag(_ enabled: Bool) -> String { "window.__potionLayout = \(enabled);\n" }

    /// Tags Notion's sidebar row and page column for `layoutCSS`, applies it while `window.__potionLayout` is set, and
    /// reports the sidebar's width (so Potion's tab row starts at its edge) and the inbox's unread count (shown on
    /// Potion's own inbox button while the sidebar is collapsed). It runs only when something changes: elements added
    /// or removed anywhere, the sidebar resizing (its collapse animates its width), and any change inside the sidebar,
    /// including text such as the inbox badge. Text edits elsewhere, like typing in a page, don't wake it.
    static let chromeScript = """
    (() => {
      if (window.__potionChromePost || !window.webkit?.messageHandlers?.\(chromeMessage)) return;
      const layoutCSS = \(jsLiteral(layoutCSS));
    \(putStyle)
      const tag = () => {
        const sidebar = document.querySelector('.notion-sidebar');
        let row = sidebar && sidebar.querySelector('[role=button]');
        while (row && row !== sidebar) {
          const box = row.getBoundingClientRect();
          if (row.children.length === 2 && getComputedStyle(row).display === 'flex' && box.height >= 32 && box.height <= 52) break;
          row = row.parentElement;
        }
        if (row && row !== sidebar && !row.classList.contains('potion-sidebar-row')) {
          document.querySelectorAll('.potion-sidebar-row').forEach(node => node.classList.remove('potion-sidebar-row'));
          row.classList.add('potion-sidebar-row');
        }
        const column = document.querySelector('.notion-frame')?.parentElement;
        if (column && column.querySelector('.notion-topbar') && !column.classList.contains('potion-page-column')) column.classList.add('potion-page-column');
        // Panels Notion pins to the top of the window beside the page (inbox, side peek) move below the tab row too.
        // Full-window layers, such as menus and dialogs, stay put.
        const panels = (element, depth) => {
          for (const child of element.children) {
            if (child.classList.contains('potion-page-column') || child.classList.contains('notion-sidebar-container')) continue;
            if (getComputedStyle(child).position === 'fixed') {
              const box = child.getBoundingClientRect();
              if (box.top < \(Int(headerHeight)) && box.height > 100 && box.width < window.innerWidth - 1) child.classList.add('potion-below-header');
            } else if (depth < 3) panels(child, depth + 1);
          }
        };
        const listener = document.querySelector('.notion-cursor-listener');
        if (listener) panels(listener, 0);
        put('potion-layout', window.__potionLayout ? layoutCSS : '');
      };
      const inboxCount = () => {
        const button = document.querySelector(\(jsLiteral(sidebarButton("Inbox"))));
        // textContent, since Notion hides the collapsed sidebar and innerText skips hidden text.
        const badge = button?.parentElement?.parentElement?.textContent.replace(/\\D/g, '') || '0';
        return parseInt(badge, 10) || 0;
      };
      let last = '';
      let observed = null;
      let scheduled = false;
      const schedule = () => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; post(); }); } };
      const resize = new ResizeObserver(() => post());
      const sidebarChanges = new MutationObserver(schedule);
      const post = () => {
        if (!document.body) return;
        tag();
        const container = document.querySelector('.notion-sidebar-container');
        if (container !== observed) {
          resize.disconnect();
          sidebarChanges.disconnect();
          if (container) {
            resize.observe(container);
            sidebarChanges.observe(container, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ['class', 'style'] });
          }
          observed = container;
        }
        let width = 0;
        if (container) {
          const box = container.getBoundingClientRect();
          if (box.left <= 1 && box.width > 40 && getComputedStyle(container).visibility !== 'hidden') width = Math.round(box.right);
        }
        const message = { sidebarWidth: width, inboxCount: inboxCount() };
        const key = JSON.stringify(message);
        if (key !== last) { last = key; window.webkit.messageHandlers.\(chromeMessage).postMessage(message); }
      };
      window.__potionChromePost = post;
      window.addEventListener('resize', schedule);
      new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
      post();
    })();
    """
    static let chromeRefresh = "\n;window.__potionChromePost && requestAnimationFrame(() => window.__potionChromePost());"

    /// Presses one of the buttons in Notion's sidebar row, which stay in the page while the sidebar is collapsed.
    static func pressSidebarButton(_ label: String) -> String {
        "document.querySelector(\(jsLiteral(sidebarButton(label))))?.click();"
    }
    private static func sidebarButton(_ label: String) -> String { ".notion-sidebar [role=button][aria-label=\"\(label)\"]" }

    /// Sends Notion the same key event as its ⌘\ shortcut, which shows or hides its sidebar.
    static let toggleSidebarScript = """
    (() => {
      const event = { key: '\\\\', code: 'Backslash', keyCode: 220, which: 220, metaKey: true, bubbles: true, cancelable: true };
      (document.activeElement || document.body).dispatchEvent(new KeyboardEvent('keydown', event));
      (document.activeElement || document.body).dispatchEvent(new KeyboardEvent('keyup', event));
    })();
    """
}
