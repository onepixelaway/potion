import SwiftUI

extension PotionTheme {
    /// Stands in for Notion's own styling wherever themes are listed.
    static let original = PotionTheme(id: ThemeStore.originalID, name: "Notion Default", subtitle: "Notion’s own look.",
                                      headingFont: "", bodyFont: "", background: "FFFFFF", surface: "F1F1EF",
                                      text: "37352F", accent: "2383E2")
    var isOriginal: Bool { id == ThemeStore.originalID }
    var fontSummary: String { isOriginal ? "System fonts" : "\(headingFont) · \(bodyFont)" }
    func headingFont(size: CGFloat) -> Font { isOriginal ? .system(size: size, weight: .semibold) : .custom(headingFont, size: size) }
}

/// A miniature page previewing a theme, for the Appearance panel.
struct ThemeCard: View {
    let theme: PotionTheme
    let isSelected: Bool
    let action: () -> Void

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
        .accessibilityLabel("\(theme.name), \(theme.fontSummary)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var page: some View {
        let text = Color(hex: theme.text)
        return VStack(alignment: .leading, spacing: 7) {
            Text("Aa").font(theme.headingFont(size: 30)).foregroundStyle(text)
            Capsule().fill(text.opacity(0.28)).frame(height: 4)
            Capsule().fill(text.opacity(0.28)).frame(width: 64, height: 4)
            HStack(spacing: 6) {
                Capsule().fill(Color(hex: theme.accent)).frame(width: 30, height: 4)
                Capsule().fill(Color(hex: theme.surface)).frame(width: 24, height: 10)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(Color(hex: theme.background), in: .rect(cornerRadius: 11))
        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(.separator) }
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
    }
}
