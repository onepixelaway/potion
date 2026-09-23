# Potion

A native macOS home for Notion, with a quieter palette and typography you can make your own. Built with SwiftUI, AppKit, and WKWebView; macOS 15 or later, with Liquid Glass on macOS 26.

## Run

Open `Potion.xcodeproj`, select the Potion scheme, and run. Or:

```sh
./scripts/build.sh
open build/Build/Products/Debug/Potion.app
```

The command-line build requires Xcode and XcodeGen (`brew install xcodegen`). The checked-in Xcode project can be built directly without XcodeGen. No API keys, Node dependencies, or remote font requests are required.

## Use

The first launch shows a welcome, then **Sign in to Notion** (Notion's own login page, shown in the window). Sign-in popups for Google, Apple and Microsoft open as a sheet over the window. Once you're in, your workspace opens with the Appearance panel showing so you can pick a theme; it closes after you choose. Later launches open straight to your last Notion page.

The window is laid out like Notion's own Mac app. Notion fills the window up to the title bar: with the sidebar open, its top row sits beside the traffic lights (collapse button first, inbox and new page at the sidebar's edge); with it collapsed, Potion shows the same three buttons, with the inbox's unread count, right after the traffic lights. Then come back and forward, your tabs in full-height cells, and reload, open in browser and **Appearance** on the right; there's no window title, since Notion's breadcrumb already says where you are. Panels Notion pins beside the page, such as the inbox, open below the tab row. Empty parts of the row move the window, and double-clicking zooms it. Each tab has its own page; ⌘-click a Notion link to open it in a background tab. Your tabs come back on relaunch.

**Appearance** opens a panel with every theme (Notion Default, the collection, and your own). **Customize…** switches the panel to the editor: fonts, text size, line spacing and colors; edits preview live, Save keeps them and Cancel restores the saved theme. Right-click a theme to customize, duplicate or delete it. The window's light or dark appearance follows the active theme. Sign out from the Potion menu or Settings (⌘,); this clears Notion's cookies and website data from Potion and returns to sign-in.

| Shortcut | Action |
| --- | --- |
| ⌘T / ⇧⌘N | New tab / new window |
| ⌘W | Close tab (the window with its last tab) |
| ⇧⌘[ / ⇧⌘] | Previous / next tab |
| ⌘\\ | Show or hide Notion's sidebar |
| ⌘[ / ⌘] | Back / Forward |
| ⌘R | Reload |
| ⇧⌘B | Open current page in browser |
| ⌃⌘I | Show or hide the Appearance panel |
| ⌃⌘1 – ⌃⌘9 | Switch theme (⌃⌘1 is Notion Default) |

Potion's shortcuts stay clear of Notion's (⌘E, ⌘N, ⌘⌥1–9 and so on), since menu shortcuts would otherwise take them from the page.

Back/forward gestures, native upload/download panels, JavaScript dialogs, load-error recovery, and external-link handoff are included.

## The collection

These are original pairing selections, chosen for contrast between expressive headings and legible body text. All six families are from Google Fonts and bundled locally under their included SIL Open Font Licenses.

| Theme | Headings | Body | Palette |
| --- | --- | --- | --- |
| Paper | [Lora](https://fonts.google.com/specimen/Lora) | [DM Sans](https://fonts.google.com/specimen/DM+Sans) | Warm paper and olive |
| Botanical | [DM Serif Display](https://fonts.google.com/specimen/DM+Serif+Display) | [Manrope](https://fonts.google.com/specimen/Manrope) | Pale sage and forest |
| Lavender | Lora | [Source Sans 3](https://fonts.google.com/specimen/Source+Sans+3) | Lilac and plum |
| Clay | DM Serif Display | DM Sans | Peach and terracotta |
| Midnight | [Space Grotesk](https://fonts.google.com/specimen/Space+Grotesk) | DM Sans | Charcoal and mist blue |
| Studio | Space Grotesk | Manrope | Chalk and graphite |

Font originals and license files: [Google Fonts repository](https://github.com/google/fonts), `Resources/Fonts`.

## Implementation

- `AppFlow.swift`: app-wide onboarding stages (welcome → sign in → workspace) and sign-out; per-window Appearance panel state and the first theme choice.
- `Tabs.swift`: a window's tabs (one web view each, sharing Notion's cookies) and their restoration at launch.
- `RootView.swift`: one window or tab; switches between stages, keeps theme injection in sync, restores its page, and presents sign-in sheets.
- `Onboarding.swift` / `MainView.swift` / `ThemeViews.swift` / `ThemeEditor.swift`: onboarding screens, the workspace window with its Notion-style header, tabs and Appearance panel, theme cards, and the theme editor.
- `PotionTheme.swift`: validated theme model, curated presets, font registration, and versioned local persistence.
- `ThemeInjection.swift`: scoped Notion styling, bundled font injection, style recovery after DOM replacement, the layout script that moves Notion's sidebar row into the title bar and reports the sidebar's width, and navigation and sign-in URL policies.
- `Workspace.swift`: persistent WKWebView, sign-in detection, sign-in popups, navigation, uploads, downloads, and error handling.
- `Resources/Preview.html`: offline sample page used by the WebKit rendering tests.

Notion and its identity providers render their own login forms. Potion does not read credentials or export cookies. The web view identifies as Safari so Google allows sign-in. Sign-in is detected when the web view reaches a workspace page. Notion's sign-in popups stay real windows (shown as sheets) so they can report back to the login page. Links you click to other sites open in your default browser; redirects during sign-in, including enterprise SSO, stay in the window. Themes are injected only into Notion domains and the bundled preview, never into identity-provider pages or Notion's login page. Font family and color inputs are validated before CSS is generated. Preferences are saved in UserDefaults under `com.potion.mac`.

## Verify

```sh
xcodebuild -project Potion.xcodeproj -scheme Potion \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

Tests cover persistence/edit/delete behavior, onboarding stages, the Appearance panel, tab titles and saved addresses, sign-in popup and redirect policy, workspace detection, unsafe input handling, URL boundaries, bundled resources, and actual WebKit rendering with live theme switching, removal, and reinjection.

## Boundaries

Notion’s DOM and CSP can change; the selectors in `ThemeInjection.swift` may need maintenance. Intentional Notion block colors, media, and code fonts are preserved. Some nested UI and database surfaces may retain their original colors. The login page and the Google sign-in popup are verified up to entering credentials; completing sign-in, SSO, uploads, and downloads require testing with your own account. Passkeys need a browser entitlement and aren't available in Potion; use email or another provider. A sign-in popup that starts on an identity provider outside the built-in list opens in your browser instead.

Local builds are not notarized. Distribution to other Macs requires your Developer ID signing and Apple notarization. Potion is independent and is not affiliated with Notion.
