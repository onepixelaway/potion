# Potion

A native macOS home for Notion, with a quieter palette and typography you can make your own. Built with SwiftUI, AppKit, and WKWebView; macOS 15 or later, with Liquid Glass on macOS 26.

## Download

**[Download Potion for Mac](https://github.com/onepixelaway/potion/releases/latest/download/Potion.dmg)** (macOS 15 or later, Apple silicon and Intel)

Open the disk image and drag Potion into Applications. The app is signed with a Developer ID and notarized by Apple, so it opens with a double-click.

## Run from source

Open `Potion.xcodeproj`, select the Potion scheme, and run. Or:

```sh
./scripts/build.sh
open build/Build/Products/Debug/Potion.app
```

The command-line build requires Xcode and XcodeGen (`brew install xcodegen`). The checked-in Xcode project can be built directly without XcodeGen. No API keys, Node dependencies, or remote font requests are required.

## Use

The first launch shows a welcome, then **Sign in to Notion** (Notion's own login page, shown in the window). Sign-in popups for Google, Apple and Microsoft open as a sheet over the window. Once you're in, your workspace opens with the Appearance panel showing so you can pick a theme; it closes after you choose. Later launches open straight to your last Notion page.

The window is laid out like Notion's own Mac app. Notion fills the window up to the title bar: with the sidebar open, its top row sits beside the traffic lights (collapse button first, inbox and new page at the sidebar's edge); with it collapsed, Potion shows the same three buttons, with the inbox's unread count, right after the traffic lights. Then come back and forward, your tabs in full-height cells, and reload, open in browser and **Appearance** on the right; there's no window title, since Notion's breadcrumb already says where you are. Panels Notion pins beside the page, such as the inbox, open below the tab row. Empty parts of the row move the window, and double-clicking zooms it. Each tab has its own page; ⌘-click a Notion link to open it in a background tab. Your tabs come back on relaunch.

**Appearance** opens a panel with every theme, light and dark (Notion Default, the collection, and your own). Click a theme to use it; double-click it (or choose **Customize…**) to open it in the editor. A theme is a color set and a font pairing, and the editor has a menu for each, offering every theme's, so any palette can go with any pairing. The pencil beside either menu shows its individual settings: the page and sidebar colors plus three text colors (page title, headings, body text) and the link accent, or the heading and body fonts, text size and line spacing. Edits preview live; Save keeps them as a theme in My Themes and Cancel restores the saved theme. Right-click a theme to customize, duplicate or delete it. The window's light or dark appearance follows the active theme. Sign out from the Potion menu or Settings (⌘,); this clears Notion's cookies and website data from Potion and returns to sign-in.

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

Twenty-four themes for reading and writing, fourteen light and ten dark. Each pairs a font pairing with a color set, and every pairing and color set can be mixed with any other in the editor. The palettes are quiet on purpose: calm pages and neutral body text, which stay comfortable on a page you read for hours in a way bold poster colors don't. Color goes to the page title, which carries each theme's main color, and to the headings: in most themes a second color that complements it (olive and rust, teal and coral, gold and rose), and in the most formal ones a softer shade of the same color (claret and dusty rose, navy and steel blue). Links take the title's color. Body text keeps at least 7:1 contrast with the page and sidebar, and titles, headings and links at least 4.5:1 (checked by the tests). Dark themes use off-white text to keep glare down.

The pairings follow well-loved Google Fonts combinations, including Marcellus + DM Sans and Libre Caslon Display + Jost from [Hearten Made](https://heartenmade.com/4-modern-google-font-pairings-youll-love/), classic display serifs such as Bodoni Moda, Prata and EB Garamond, and screen-reading faces such as Literata, Source Serif 4 and Atkinson Hyperlegible Next. All 35 families are from Google Fonts and bundled locally under their included SIL Open Font Licenses. A page loads only the two families its theme uses.

| Theme | Headings | Body | Palette |
| --- | --- | --- | --- |
| Paper | [Lora](https://fonts.google.com/specimen/Lora) | [DM Sans](https://fonts.google.com/specimen/DM+Sans) | Warm paper; olive title, rust headings |
| Botanical | [DM Serif Display](https://fonts.google.com/specimen/DM+Serif+Display) | [Manrope](https://fonts.google.com/specimen/Manrope) | Pale sage; forest title, berry headings |
| Lavender | Lora | [Source Sans 3](https://fonts.google.com/specimen/Source+Sans+3) | Lilac; violet title, ochre headings |
| Clay | DM Serif Display | DM Sans | Peach; terracotta title, teal headings |
| Studio | [Space Grotesk](https://fonts.google.com/specimen/Space+Grotesk) | Manrope | Chalk; indigo title, sienna headings |
| Linen | [Marcellus](https://fonts.google.com/specimen/Marcellus) | DM Sans | Ivory; bronze title, slate blue headings |
| Porcelain | [Libre Caslon Display](https://fonts.google.com/specimen/Libre+Caslon+Display) | [Jost](https://fonts.google.com/specimen/Jost) | Cool white; delft blue title, burnt orange headings |
| Blossom | [Cormorant](https://fonts.google.com/specimen/Cormorant) | [Karla](https://fonts.google.com/specimen/Karla) | Blush; rose title, sage headings |
| Sea Glass | [Instrument Serif](https://fonts.google.com/specimen/Instrument+Serif) | [Instrument Sans](https://fonts.google.com/specimen/Instrument+Sans) | Pale aqua; teal title, coral headings |
| Library | [Newsreader](https://fonts.google.com/specimen/Newsreader) | [Literata](https://fonts.google.com/specimen/Literata) | Parchment; oxblood title, forest headings |
| Fog | [Sora](https://fonts.google.com/specimen/Sora) | [Inter](https://fonts.google.com/specimen/Inter) | Cool grey; indigo title, amber headings |
| Meadow | [Fraunces](https://fonts.google.com/specimen/Fraunces) | [Figtree](https://fonts.google.com/specimen/Figtree) | Buttercream; leaf title, violet headings |
| Champagne | [Bodoni Moda](https://fonts.google.com/specimen/Bodoni+Moda) | [Hanken Grotesk](https://fonts.google.com/specimen/Hanken+Grotesk) | Ivory; claret title, dusty rose headings |
| Atelier | [Gilda Display](https://fonts.google.com/specimen/Gilda+Display) | [Mulish](https://fonts.google.com/specimen/Mulish) | Gallery white; navy title, steel blue headings |
| Midnight | Space Grotesk | DM Sans | Charcoal; periwinkle title, peach headings |
| Ink | [Playfair Display](https://fonts.google.com/specimen/Playfair+Display) | [Source Serif 4](https://fonts.google.com/specimen/Source+Serif+4) | Navy; gold title, rose headings |
| Forest | [Crimson Pro](https://fonts.google.com/specimen/Crimson+Pro) | [Work Sans](https://fonts.google.com/specimen/Work+Sans) | Deep green; mint title, coral headings |
| Espresso | [Young Serif](https://fonts.google.com/specimen/Young+Serif) | [Albert Sans](https://fonts.google.com/specimen/Albert+Sans) | Dark roast; caramel title, sky blue headings |
| Plum | [Outfit](https://fonts.google.com/specimen/Outfit) | Source Serif 4 | Aubergine; lilac title, lime headings |
| Terminal | [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono) | Inter | Graphite; mint title, amber headings |
| Harbor | [Atkinson Hyperlegible Next](https://fonts.google.com/specimen/Atkinson+Hyperlegible+Next) | Atkinson Hyperlegible Next | Deep teal; aqua title, coral headings |
| Ember | [Bitter](https://fonts.google.com/specimen/Bitter) | Source Sans 3 | Charcoal; coral title, gold headings |
| Velvet | [Prata](https://fonts.google.com/specimen/Prata) | Lora | Bordeaux black; rose gold title, muted rose headings |
| Nocturne | [EB Garamond](https://fonts.google.com/specimen/EB+Garamond) | Figtree | Warm charcoal; antique gold title, deeper gold headings |

Font originals and license files: [Google Fonts repository](https://github.com/google/fonts), `Resources/Fonts`.

## Implementation

- `AppFlow.swift`: app-wide onboarding stages (welcome → sign in → workspace) and sign-out; per-window Appearance panel state and the first theme choice.
- `Tabs.swift`: a window's tabs (one web view each, sharing Notion's cookies) and their restoration at launch.
- `RootView.swift`: one window or tab; switches between stages, keeps theme injection in sync, restores its page, and presents sign-in sheets.
- `Onboarding.swift` / `MainView.swift` / `ThemeViews.swift` / `ThemeEditor.swift`: onboarding screens, the workspace window with its Notion-style header, tabs and Appearance panel, theme cards, and the theme editor.
- `PotionTheme.swift`: validated theme model (a font pairing and a color set with title, heading and text colors), the preset collection, the font catalog read from the bundled files, and local persistence.
- `ThemeInjection.swift`: scoped Notion styling, with separate colors for the page title, headings and body text; injection of the theme's two font families, style recovery after DOM replacement, and the layout script that moves Notion's sidebar row into the title bar and reports the sidebar's width.
- `NavigationPolicy.swift`: which pages load in Potion, open in the browser or count as signed in, and sign-in popup rules.
- `Workspace.swift`: persistent WKWebView, sign-in detection, sign-in popups, navigation, uploads, downloads, and error handling.
- `SharedViews.swift`: the page error view, window access, and view helpers shared across screens.
- `Resources/Preview.html`: offline sample page used by the WebKit rendering tests.

Notion and its identity providers render their own login forms. Potion does not read credentials or export cookies. The web view identifies as Safari so Google allows sign-in. Sign-in is detected when the web view reaches a workspace page. Notion's sign-in popups stay real windows (shown as sheets) so they can report back to the login page. Links you click to other sites open in your default browser; redirects during sign-in, including enterprise SSO, stay in the window. Themes are injected only into Notion domains and the bundled preview, never into identity-provider pages or Notion's login page. Font family and color inputs are validated before CSS is generated. Preferences are saved in UserDefaults under `com.potion.mac`.

## Verify

```sh
xcodebuild -project Potion.xcodeproj -scheme Potion \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

Tests cover persistence/edit/delete behavior and migration of older themes, the presets' contrast and pairings, onboarding stages, the Appearance panel, tab titles and saved addresses, sign-in popup and redirect policy, workspace detection, unsafe input handling, URL boundaries, bundled resources, and actual WebKit rendering with live theme switching, removal, and reinjection.

## Boundaries

Notion’s DOM and CSP can change; the selectors in `ThemeInjection.swift` may need maintenance. Intentional Notion block colors, media, and code fonts are preserved. Some nested UI and database surfaces may retain their original colors. The login page and the Google sign-in popup are verified up to entering credentials; completing sign-in, SSO, uploads, and downloads require testing with your own account. Passkeys need a browser entitlement and aren't available in Potion; use email or another provider. A sign-in popup that starts on an identity provider outside the built-in list opens in your browser instead.

Local builds are not notarized. `./scripts/release.sh` builds the downloadable disk image: it signs Potion with the team's Developer ID through the Apple account signed in to Xcode, waits for Apple's notarization, and writes `build/Potion.dmg`. Potion is independent and is not affiliated with Notion.
