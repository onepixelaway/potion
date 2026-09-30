import Foundation

enum ThemeInjection {
    /// Encodes a value as a JavaScript literal, for embedding in injected scripts.
    private static func jsLiteral<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        // Slashes are common in the embedded fonts' base64 and need no escaping.
        encoder.outputFormatting = .withoutEscapingSlashes
        return String(data: try! encoder.encode(value), encoding: .utf8)!
    }

    /// A family's @font-face rule, with the font file embedded so pages need no font requests.
    private static func fontFace(_ family: String) -> String? {
        guard let url = FontCatalog.url(for: family), let data = try? Data(contentsOf: url) else { return nil }
        return "@font-face { font-family: '\(family)'; src: url(data:font/ttf;base64,\(data.base64EncodedString())) format('truetype'); font-weight: 100 900; font-display: swap; }"
    }
    /// The last fonts sent, as a JavaScript literal, shared by every tab since they all show the same theme.
    @MainActor private static var fontsCache: (fonts: ThemeFonts, literal: String)?
    /// A theme's two font families as one embedded stylesheet, or an empty one for Notion's own look.
    @MainActor private static func fontsLiteral(_ fonts: ThemeFonts?) -> String {
        guard let fonts else { return jsLiteral("") }
        if let fontsCache, fontsCache.fonts == fonts { return fontsCache.literal }
        let literal = jsLiteral(Set([fonts.heading, fonts.body]).sorted().compactMap(fontFace).joined(separator: "\n"))
        fontsCache = (fonts, literal)
        return literal
    }

    /// Notion's page title. Links to other pages, inside a page or in the sidebar, use the same class.
    private static let pageTitle = ".notion-page-block:not(.notion-page-content *, .notion-sidebar *)"
    private static let headingBlocks = ".notion-header-block, .notion-sub_header-block, .notion-sub_sub_header-block"

    static func css(for input: PotionTheme, changesSidebarFont: Bool) -> String {
        let t = input.validated
        let c = t.colors
        // The sidebar inherits the body font from Notion's app container, unless it keeps Notion's own font, which
        // `runtime` reads from that container.
        let sidebarFont = changesSidebarFont ? "" : """
        .notion-sidebar-container {
          font-family: var(--potion-notion-font, ui-sans-serif, -apple-system, sans-serif) !important;
        }
        """
        // Page colors are written out rather than read from variables, and only the page's outer layers paint them:
        // the text column stays transparent, so it can never show a different shade than the page around it.
        // Fonts match text whether or not it's editable, since Notion makes trashed and shared pages read-only.
        // Title and heading blocks set their own text color, both directly and through Notion's text variable, which
        // also recolors text Notion marks with its default color. Block colors people choose stay as they are.
        return """
        :root {
          --potion-bg: #\(c.background);
          --potion-surface: #\(c.surface);
          --potion-text: #\(c.text);
          --potion-accent: #\(c.accent);
          color-scheme: \(t.isDark ? "dark" : "light");
        }
        :root,
        .notion-light-theme,
        .notion-dark-theme,
        .notion-app-inner {
          --c-bacPri: #\(c.background) !important;
          --c-bacSec: #\(c.surface) !important;
          --c-bacTer: #\(c.surface) !important;
          --c-bacEle: #\(c.background) !important;
          --c-popBac: #\(c.background) !important;
          --c-texPri: #\(c.text) !important;
          --c-texSec: #\(c.text)B3 !important;
          --c-texTer: #\(c.text)8C !important;
          --c-icoPri: #\(c.text) !important;
          --c-icoSec: #\(c.text)99 !important;
          --c-borPri: #\(c.text)20 !important;
          --c-borSec: #\(c.text)14 !important;
          --c-bluTexAccPri: #\(c.accent) !important;
          --ca-staHov: #\(c.accent)14 !important;
        }
        body,
        .notion-app-inner {
          background: #\(c.background) !important;
          color: #\(c.text) !important;
        }
        \(pageTitle),
        .potion-preview h1 {
          --c-texPri: #\(c.title) !important;
          color: #\(c.title);
        }
        \(headingBlocks),
        .potion-preview h2,
        .potion-preview h3 {
          --c-texPri: #\(c.heading) !important;
          color: #\(c.heading);
        }
        .notion-app-inner,
        .notion-page-content,
        .potion-preview {
          font-family: '\(t.fonts.body)', sans-serif !important;
        }
        \(sidebarFont)
        .notion-cursor-listener,
        .notion-frame,
        .notion-scroller.vertical,
        .notion-topbar {
          background-color: #\(c.background) !important;
        }
        .notion-page-content {
          background-color: transparent !important;
        }
        .notion-sidebar-container,
        .notion-sidebar {
          background-color: #\(c.surface) !important;
        }
        .notion-sidebar-container .notion-scroller.vertical {
          background-color: transparent !important;
        }
        .notion-page-content,
        .notion-text-block [contenteditable],
        .notion-bulleted_list-block [contenteditable],
        .notion-numbered_list-block [contenteditable],
        .notion-to_do-block [contenteditable] {
          font-size: \(t.fontSize)px !important;
          line-height: \(t.lineHeight) !important;
        }
        :is(\(pageTitle), \(headingBlocks)) [contenteditable],
        .potion-preview h1,
        .potion-preview h2,
        .potion-preview h3 {
          font-family: '\(t.fonts.heading)', serif !important;
        }
        .notion-page-content a,
        .potion-preview a {
          color: var(--potion-accent) !important;
        }
        :is(.notion-page-content, \(pageTitle))
          :is([style*='color: rgb(55, 53, 47)'], [style*='color: rgba(255, 255, 255, 0.81)']) {
          color: var(--c-texPri) !important;
        }
        .notion-code-block,
        .notion-code-block *,
        code,
        pre {
          font-family: ui-monospace, SFMono-Regular, monospace !important;
        }
        ::selection {
          background: #\(c.accent)40;
        }
        .potion-preview {
          font-size: \(t.fontSize)px;
          line-height: \(t.lineHeight);
        }
        """
    }

    /// What Potion puts on a tab's pages: a theme (nil for Notion's own look) and Notion's Mac-app layout.
    struct PageStyle: Equatable {
        var theme: PotionTheme?
        var layout = false
        var changesSidebarFont = false
        var fonts: ThemeFonts? { theme?.fonts }
    }

    /// Sends a page its style through `runtime`. The fonts, which are large and rarely change, go only when asked for.
    @MainActor static func update(_ style: PageStyle, withFonts: Bool) -> String {
        let fonts = withFonts ? ", fonts: \(fontsLiteral(style.fonts))" : ""
        let dark = style.theme.map { "\($0.isDark)" } ?? "null"
        return "window.__potion?.update({ css: \(jsLiteral(style.theme.map { css(for: $0, changesSidebarFont: style.changesSidebarFont) } ?? "")), dark: \(dark), layout: \(style.layout)\(fonts) });"
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
    /// Potion's back, forward and tab row. The elements are tagged by `runtime`. The page and sidebar scroll
    /// without visible scroll bars; wide tables and code blocks keep theirs.
    private static let layoutCSS = """
    .potion-sidebar-row {
      height: \(Int(headerHeight))px !important;
      padding-inline-start: \(Int(sidebarButtonX))px !important;
    }
    .potion-page-column {
      padding-top: \(Int(headerHeight))px !important;
    }
    .potion-below-header {
      top: \(Int(headerHeight))px !important;
      height: calc(100% - \(Int(headerHeight))px) !important;
      max-height: calc(100% - \(Int(headerHeight))px) !important;
    }
    .notion-frame .notion-scroller.vertical,
    .notion-sidebar .notion-scroller.vertical {
      scrollbar-width: none !important;
    }
    .notion-frame .notion-scroller.vertical::-webkit-scrollbar,
    .notion-sidebar .notion-scroller.vertical::-webkit-scrollbar {
      display: none !important;
      width: 0 !important;
    }
    """

    /// Installed on every page before its style. Defines `window.__potion.update`, which puts the theme, its fonts and
    /// the layout on the page as three style elements, and one observer that puts them back whenever Notion replaces
    /// the part of the page holding them and keeps Notion's own font at hand for the sidebar. It also tags Notion's
    /// sidebar row and page column for `layoutCSS` and reports the sidebar's width (so Potion's tab row starts at its
    /// edge), the inbox's unread count (shown on Potion's own inbox button while the sidebar is collapsed), and
    /// Notion's appearance setting when it's Light or Dark (so Potion's window matches the page). That runs at most
    /// once a frame, and only when something changes: elements added or removed anywhere, the sidebar resizing (its
    /// collapse animates its width), and any change inside the sidebar, including text such as the inbox badge. Text
    /// edits elsewhere, like typing in a page, don't wake it.
    static let runtime = """
    (() => {
      // Only Notion's pages and the offline preview are styled.
      const domains = \(jsLiteral(NavigationPolicy.notionDomains));
      const onNotion =
        location.protocol === 'https:' &&
        domains.some(
          domain => location.hostname === domain || location.hostname.endsWith('.' + domain),
        );
      if (!onNotion && location.protocol !== 'file:') return;
      if (window.__potion) return;
      const layoutCSS = \(jsLiteral(layoutCSS));
      const state = { css: '', fonts: '', dark: null, layout: false };
      // Creates or updates one of Potion's style elements, leaving it alone when the CSS is unchanged.
      const put = (id, css) => {
        let node = document.getElementById(id);
        if (!node) {
          node = document.createElement('style');
          node.id = id;
          (document.head || document.documentElement).appendChild(node);
        }
        if (node.textContent !== css) node.textContent = css;
      };
      const styleIDs = ['potion-fonts', 'potion-theme', 'potion-layout'];
      // Notion sets its own font on its app container, where a theme's body font overrides it. Kept as a variable, so
      // the sidebar can keep Notion's font under a theme. Like the style elements, it's checked on every change rather
      // than once a frame, since tabs in the background don't draw frames.
      let notionFont = '';
      const keepNotionFont = () => {
        const font = document.querySelector('.notion-app-inner')?.style.fontFamily;
        if (font && font !== notionFont) {
          notionFont = font;
          document.documentElement.style.setProperty('--potion-notion-font', font);
        }
      };
      const render = () => {
        if (!document.documentElement) return;
        keepNotionFont();
        put('potion-fonts', state.fonts);
        put('potion-theme', state.css);
        put('potion-layout', state.layout ? layoutCSS : '');
        showMode();
      };
      // Notion marks its light or dark mode with a class on its app container and overlays, following its own
      // appearance setting, and adds `dark` to the body in dark mode. While a theme is on, the page shows the theme's
      // mode instead, so Notion draws its settings, menus and controls for the theme's background. Turning the theme
      // off goes back to Notion's own setting.
      const modeClasses = '.notion-dark-theme, .notion-light-theme';
      const isNotionPage = () =>
        document.querySelector('.notion-app-inner')?.matches(modeClasses) ?? false;
      // Notion's appearance setting: 'light', 'dark', or anything else to follow the system.
      const notionSetting = () => {
        try {
          return JSON.parse(localStorage.getItem('theme'))?.mode;
        } catch {
          return null;
        }
      };
      const notionDark = () => {
        const mode = notionSetting();
        return (
          mode === 'dark' || (mode !== 'light' && matchMedia('(prefers-color-scheme: dark)').matches)
        );
      };
      let themedMode = false;
      const showMode = () => {
        if (!isNotionPage() || (state.dark === null && !themedMode)) return;
        themedMode = state.dark !== null;
        const dark = state.dark ?? notionDark();
        const [on, off] = dark
          ? ['notion-dark-theme', 'notion-light-theme']
          : ['notion-light-theme', 'notion-dark-theme'];
        if (!document.querySelector('.' + off) && document.body.classList.contains('dark') === dark) {
          return;
        }
        document.querySelectorAll('.' + off).forEach(node => node.classList.replace(off, on));
        document.body.classList.toggle('dark', dark);
      };
      const tag = () => {
        const sidebar = document.querySelector('.notion-sidebar');
        let row = sidebar && sidebar.querySelector('[role=button]');
        while (row && row !== sidebar) {
          const box = row.getBoundingClientRect();
          if (
            row.children.length === 2 &&
            getComputedStyle(row).display === 'flex' &&
            box.height >= 32 &&
            box.height <= 52
          ) {
            break;
          }
          row = row.parentElement;
        }
        if (row && row !== sidebar && !row.classList.contains('potion-sidebar-row')) {
          document
            .querySelectorAll('.potion-sidebar-row')
            .forEach(node => node.classList.remove('potion-sidebar-row'));
          row.classList.add('potion-sidebar-row');
        }
        const column = document.querySelector('.notion-frame')?.parentElement;
        if (
          column &&
          column.querySelector('.notion-topbar') &&
          !column.classList.contains('potion-page-column')
        ) {
          column.classList.add('potion-page-column');
        }
        // Panels Notion pins to the top of the window beside the page (inbox, side peek) move below the tab row too.
        // Full-window layers, such as menus and dialogs, stay put.
        const panels = (element, depth) => {
          for (const child of element.children) {
            if (
              child.classList.contains('potion-page-column') ||
              child.classList.contains('notion-sidebar-container')
            ) {
              continue;
            }
            if (getComputedStyle(child).position === 'fixed') {
              const box = child.getBoundingClientRect();
              if (
                box.top < \(Int(headerHeight)) &&
                box.height > 100 &&
                box.width < window.innerWidth - 1
              ) {
                child.classList.add('potion-below-header');
              }
            } else if (depth < 3) panels(child, depth + 1);
          }
        };
        const listener = document.querySelector('.notion-cursor-listener');
        if (listener) panels(listener, 0);
      };
      const inboxCount = () => {
        const button = document.querySelector(\(jsLiteral(sidebarButton("Inbox"))));
        // textContent, since Notion hides the collapsed sidebar and innerText skips hidden text.
        const badge = button?.parentElement?.parentElement?.textContent.replace(/\\D/g, '') || '0';
        return parseInt(badge, 10) || 0;
      };
      const handler = window.webkit?.messageHandlers?.\(chromeMessage);
      let last = '';
      let observed = null;
      let scheduled = false;
      const schedule = () => {
        if (!scheduled) {
          scheduled = true;
          requestAnimationFrame(() => {
            scheduled = false;
            refresh();
          });
        }
      };
      const resize = new ResizeObserver(schedule);
      const sidebarChanges = new MutationObserver(schedule);
      const refresh = () => {
        if (!document.body) return;
        showMode();
        tag();
        const container = document.querySelector('.notion-sidebar-container');
        if (container !== observed) {
          resize.disconnect();
          sidebarChanges.disconnect();
          if (container) {
            resize.observe(container);
            sidebarChanges.observe(container, {
              subtree: true,
              childList: true,
              characterData: true,
              attributes: true,
              attributeFilter: ['class', 'style'],
            });
          }
          observed = container;
        }
        let width = 0;
        if (container) {
          const box = container.getBoundingClientRect();
          if (box.left <= 1 && box.width > 40 && getComputedStyle(container).visibility !== 'hidden') {
            width = Math.round(box.right);
          }
        }
        const setting = notionSetting();
        const message = {
          sidebarWidth: width,
          inboxCount: inboxCount(),
          notionAppearance:
            isNotionPage() && (setting === 'light' || setting === 'dark') ? setting : null,
        };
        const key = JSON.stringify(message);
        if (handler && key !== last) {
          last = key;
          handler.postMessage(message);
        }
      };
      window.__potion = {
        update(next) {
          Object.assign(state, next);
          render();
          schedule();
        },
      };
      window.addEventListener('resize', schedule);
      new MutationObserver(() => {
        if (styleIDs.some(id => !document.getElementById(id))) render();
        else keepNotionFont();
        schedule();
      }).observe(document.documentElement, { childList: true, subtree: true });
      // Notion changes the body's classes when its appearance setting changes.
      if (document.body) {
        new MutationObserver(() => {
          showMode();
          schedule();
        }).observe(document.body, { attributes: true, attributeFilter: ['class'] });
      }
      render();
      refresh();
    })();
    """

    /// Presses one of the buttons in Notion's sidebar row, which stay in the page while the sidebar is collapsed.
    static func pressSidebarButton(_ label: String) -> String {
        "document.querySelector(\(jsLiteral(sidebarButton(label))))?.click();"
    }
    private static func sidebarButton(_ label: String) -> String { ".notion-sidebar [role=button][aria-label=\"\(label)\"]" }

    /// Sends Notion the same key event as its ⌘\ shortcut, which shows or hides its sidebar.
    static let toggleSidebarScript = """
    (() => {
      const event = {
        key: '\\\\',
        code: 'Backslash',
        keyCode: 220,
        which: 220,
        metaKey: true,
        bubbles: true,
        cancelable: true,
      };
      (document.activeElement || document.body).dispatchEvent(new KeyboardEvent('keydown', event));
      (document.activeElement || document.body).dispatchEvent(new KeyboardEvent('keyup', event));
    })();
    """
}
