import SwiftUI

extension PotionTheme {
    /// Stands in for Notion's own styling wherever themes are listed.
    static let original = PotionTheme(id: ThemeStore.originalID, name: "Notion Default", subtitle: "Notion’s own look.",
                                      fonts: ThemeFonts(heading: "", body: ""),
                                      colors: ThemeColors(background: "FFFFFF", surface: "F1F1EF", title: "37352F",
                                                          heading: "37352F", text: "37352F", accent: "2383E2"))
    var isOriginal: Bool { id == ThemeStore.originalID }
    var fontSummary: String { isOriginal ? "System fonts" : fonts.name }
    func headingFont(size: CGFloat) -> Font { isOriginal ? .system(size: size, weight: .semibold) : .custom(fonts.heading, size: size) }
}

extension ThemeColors {
    /// The presets' swatches, drawn once, so a menu isn't handed new images on every edit.
    private static let presetSwatches = Dictionary(PotionTheme.presets.map { ($0.colors, $0.colors.makeSwatch()) },
                                                   uniquingKeysWith: { first, _ in first })
    /// A small picture of the palette for menus: the page, with its title, heading and text colors on it.
    var swatch: NSImage { Self.presetSwatches[self] ?? makeSwatch() }

    private func makeSwatch() -> NSImage {
        let image = NSImage(size: NSSize(width: 34, height: 16), flipped: false) { rect in
            let page = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            NSColor(hex: background).setFill()
            page.fill()
            NSColor.black.withAlphaComponent(0.18).setStroke()
            page.stroke()
            for (index, hex) in [title, heading, text].enumerated() {
                NSColor(hex: hex).setFill()
                NSBezierPath(ovalIn: NSRect(x: 6 + CGFloat(index) * 8, y: 5, width: 6, height: 6)).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}

/// A miniature page previewing a theme, for the Appearance panel. Double-clicking opens the theme in the editor.
struct ThemeCard: View {
    let theme: PotionTheme
    let isSelected: Bool
    let action: () -> Void
    let open: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                page
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                            .padding(-5)
                            .opacity(isSelected ? 1 : 0)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.name).font(.headline)
                    Text(theme.fontSummary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(.horizontal, 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded(open))
        .accessibilityLabel("\(theme.name), \(theme.fontSummary)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: "Customize", open)
    }

    /// The title, a heading, body text, and a link and surface, each in the theme's own color.
    private var page: some View {
        let colors = theme.colors
        let text = Color(hex: colors.text)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Aa").font(theme.headingFont(size: 28)).foregroundStyle(Color(hex: colors.title))
            Capsule().fill(Color(hex: colors.heading)).frame(width: 52, height: 5)
            Capsule().fill(text.opacity(0.32)).frame(height: 4)
            Capsule().fill(text.opacity(0.32)).frame(width: 64, height: 4)
            HStack(spacing: 6) {
                Capsule().fill(Color(hex: colors.accent)).frame(width: 30, height: 4)
                Capsule().fill(Color(hex: colors.surface)).frame(width: 24, height: 10)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(Color(hex: colors.background), in: .rect(cornerRadius: 11))
        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(.separator) }
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
    }
}
