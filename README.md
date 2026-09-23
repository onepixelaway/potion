# Potion

A native macOS home for Notion, with a quieter palette and typography you can make your own. Built with SwiftUI, AppKit, and WKWebView; macOS 14 or later.

## Run

Open `Potion.xcodeproj`, select the Potion scheme, and run. Or:

```sh
./scripts/build.sh
open build/Build/Products/Debug/Potion.app
```

The command-line build requires Xcode and XcodeGen (`brew install xcodegen`). The checked-in Xcode project can be built directly without XcodeGen. No API keys, Node dependencies, or remote font requests are required.

## Use

Potion opens to **The fitting room**, an offline sample page. Choose a collection theme to preview it immediately. **Open Notion** loads Notion’s actual website; sign in there using your Notion account. Cookies and website data use WebKit’s persistent data store. Returning to Notion restores your last Notion page path.

**Mix your own theme** makes a new theme. **Customize** edits the selected custom theme or creates a copy of a preset. Choose heading and body fonts, page/surface/text/accent colors, size, and line spacing. Changes preview live; Save persists them and Cancel restores your existing theme. Right-click a custom theme to edit or delete it. The Theme switch restores Notion’s own styling without a reload.

| Shortcut | Action |
| --- | --- |
| ⌘O | Open Notion |
| ⌘R | Reload |
| ⇧⌘P | Theme preview |
| ⇧⌘B | Open current page in browser |
| ⇧⌘T | Show or hide the theme collection |

Back/forward gestures and buttons, native upload/download panels, authentication popups, JavaScript dialogs, load-error recovery, and external-link handoff are included.

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

- `PotionTheme.swift`: validated theme model, curated presets, font registration, and versioned local persistence.
- `ThemeInjection.swift`: scoped Notion styling, bundled font injection, style recovery after DOM replacement, and navigation URL policies.
- `Workspace.swift`: persistent WKWebView, navigation, authentication windows, uploads, downloads, and error handling.
- `ContentView.swift` / `ThemeEditor.swift`: native theme gallery and customization controls.
- `Resources/Preview.html`: offline preview document, kept separate from the live Notion workspace.

Notion and its authentication providers render their own login forms. Potion does not read credentials or export cookies. Non-Notion links open in your default browser; known sign-in providers may remain in the web view. Themes are injected only into Notion domains and the bundled preview, never into identity-provider pages. Font family and color inputs are validated before CSS is generated. Theme preferences are saved in UserDefaults under `com.potion.mac`.

## Verify

```sh
xcodebuild -project Potion.xcodeproj -scheme Potion \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

Tests cover persistence/edit/delete behavior, unsafe input handling, URL boundaries, bundled resources, and actual WebKit rendering with live theme switching, removal, and reinjection.

## Boundaries

Notion’s DOM and CSP can change; the selectors in `ThemeInjection.swift` may need maintenance. Intentional Notion block colors, media, and code fonts are preserved. Some nested UI and database surfaces may retain their original colors. The embedded login page is verified, but authenticated editing, SSO, uploads, and downloads require testing with your own account. Some identity providers restrict embedded-browser login; use Notion’s email sign-in option when available. Enterprise identity-provider domains beyond the built-in list open externally.

Local builds are not notarized. Distribution to other Macs requires your Developer ID signing and Apple notarization. Potion is independent and is not affiliated with Notion.
