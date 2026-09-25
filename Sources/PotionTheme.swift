import AppKit
import SwiftUI
import CoreText

/// A theme's two typefaces: one for the page title and headings, one for everything else.
struct ThemeFonts: Codable, Hashable {
    var heading: String
    var body: String
    var name: String { heading == body ? heading : "\(heading) & \(body)" }
    /// Whether this is one of the presets' pairings, as opposed to fonts someone mixed.
    var isPreset: Bool { PotionTheme.fontSets.contains(self) }
}

/// A theme's palette: the page and its surfaces, three text colors (page title, headings, body text), and an accent
/// for links. Colors are six-digit hex strings.
struct ThemeColors: Codable, Hashable {
    var background: String
    var surface: String
    var title: String
    var heading: String
    var text: String
    var accent: String

    /// Every color, labeled as the editor shows it.
    static let fields: [(label: String, key: WritableKeyPath<ThemeColors, String>)] = [
        ("Page", \.background), ("Sidebar and Surfaces", \.surface), ("Page Title", \.title),
        ("Headings", \.heading), ("Text", \.text), ("Accent and Links", \.accent),
    ]
    var isDark: Bool { NSColor(hex: background).brightnessComponent < 0.45 }
    /// Whether these are one of the presets' palettes, as opposed to colors someone mixed.
    var isPreset: Bool { PotionTheme.presets.contains { $0.colors == self } }
}

extension ThemeColors {
    init(_ background: String, _ surface: String, _ title: String, _ heading: String, _ text: String, _ accent: String) {
        self.init(background: background, surface: surface, title: title, heading: heading, text: text, accent: accent)
    }
}

/// A theme is a font pairing and a color set, plus reading size and spacing. Every preset's fonts and colors are also
/// offered on their own, so any pairing can be mixed with any palette.
struct PotionTheme: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var fonts: ThemeFonts
    var colors: ThemeColors
    var fontSize: Double = 16
    var lineHeight: Double = 1.65
    var isCustom = false

    private static func preset(_ id: String, _ name: String, _ heading: String, _ body: String, _ colors: ThemeColors) -> PotionTheme {
        PotionTheme(id: id, name: name, fonts: ThemeFonts(heading: heading, body: body), colors: colors)
    }

    /// Colors run page, surfaces, title, headings, text, accent. The title carries the theme's main color and headings
    /// either a second one that complements it or a softer shade of the same one, while body text stays a quiet neutral
    /// with at least 7:1 contrast against the page and sidebar; titles, headings and links keep at least 4.5:1. Links
    /// take the title's color, and dark themes keep text off pure white to cut glare.
    static let presets: [PotionTheme] = [
        preset("paper", "Paper", "Lora", "DM Sans",
               ThemeColors("F8F5EF", "EEEAE2", "4B672A", "9A4A2C", "3A3E36", "4B672A")),
        preset("botanical", "Botanical", "DM Serif Display", "Manrope",
               ThemeColors("EEF2EC", "DFE8DC", "1E6A4E", "8C3A5E", "2E3B34", "1E6A4E")),
        preset("lavender", "Lavender", "Lora", "Source Sans 3",
               ThemeColors("F6F3F9", "E9E3F1", "5A3D9A", "805A0E", "3E3750", "5A3D9A")),
        preset("clay", "Clay", "DM Serif Display", "DM Sans",
               ThemeColors("FBF4EE", "F1E3D8", "A0462A", "2B6966", "47352E", "9A4424")),
        preset("mono", "Studio", "Space Grotesk", "Manrope",
               ThemeColors("F6F6F4", "E9E9E6", "33448A", "9A552A", "343735", "33448A")),
        preset("linen", "Linen", "Marcellus", "DM Sans",
               ThemeColors("FAF7F2", "EFEAE2", "86552A", "3C5878", "3D3833", "86552A")),
        preset("porcelain", "Porcelain", "Libre Caslon Display", "Jost",
               ThemeColors("F5F7FA", "E6ECF2", "24528F", "A04A22", "2F3A46", "24528F")),
        preset("blossom", "Blossom", "Cormorant", "Karla",
               ThemeColors("FBF5F5", "F2E5E5", "9C3654", "4A6B48", "4A3A3D", "9C3654")),
        preset("seaglass", "Sea Glass", "Instrument Serif", "Instrument Sans",
               ThemeColors("F0F5F4", "DFEBE9", "16665F", "A04636", "2D3E3C", "16665F")),
        preset("library", "Library", "Newsreader", "Literata",
               ThemeColors("F7F2E8", "EBE3D2", "7C2B28", "2C5C4B", "3B342A", "7C2B28")),
        preset("fog", "Fog", "Sora", "Inter",
               ThemeColors("F4F5F7", "E5E7EB", "3C4AAE", "8A5A0C", "333844", "3C4AAE")),
        preset("meadow", "Meadow", "Fraunces", "Figtree",
               ThemeColors("FAF8EE", "EFEBD7", "56661A", "774790", "3F3B2B", "56661A")),
        preset("champagne", "Champagne", "Bodoni Moda", "Hanken Grotesk",
               ThemeColors("FAF6F2", "F0E8E2", "7A2B3A", "9E5462", "3D3537", "8E3A4A")),
        preset("atelier", "Atelier", "Gilda Display", "Mulish",
               ThemeColors("F6F6F2", "EAEAE4", "1F3A5F", "48678E", "33373D", "2F5A8C")),
        preset("midnight", "Midnight", "Space Grotesk", "DM Sans",
               ThemeColors("1F242B", "2A313A", "A9C4F0", "EDB38C", "D8DCE1", "A9C4F0")),
        preset("ink", "Ink", "Playfair Display", "Source Serif 4",
               ThemeColors("161A24", "202634", "E3C681", "DCA3BC", "CDD2DC", "E3C681")),
        preset("forest", "Forest", "Crimson Pro", "Work Sans",
               ThemeColors("172019", "212C24", "A6D6B6", "E7AAA0", "D2DCD4", "A6D6B6")),
        preset("espresso", "Espresso", "Young Serif", "Albert Sans",
               ThemeColors("1E1A17", "2A2420", "E8B185", "A3C1DC", "DDD4CA", "E8B185")),
        preset("plum", "Plum", "Outfit", "Source Serif 4",
               ThemeColors("1F1B25", "2A2431", "D0B2F2", "CBDB92", "DAD3E2", "D0B2F2")),
        preset("terminal", "Terminal", "JetBrains Mono", "Inter",
               ThemeColors("161719", "202225", "9FE0B8", "EBC57C", "D5D6D2", "9FE0B8")),
        preset("harbor", "Harbor", "Atkinson Hyperlegible Next", "Atkinson Hyperlegible Next",
               ThemeColors("132226", "1C3034", "8ED9D1", "F2A993", "CEDCDC", "8ED9D1")),
        preset("ember", "Ember", "Bitter", "Source Sans 3",
               ThemeColors("1C1A1C", "272427", "EFA79D", "DCC684", "DCD5D7", "EFA79D")),
        preset("velvet", "Velvet", "Prata", "Lora",
               ThemeColors("1D1618", "292023", "EDBBAE", "C99B91", "DDD2D2", "E3AE9F")),
        preset("nocturne", "Nocturne", "EB Garamond", "Figtree",
               ThemeColors("1A1A17", "25251F", "E3CB8F", "BFA56E", "D9D6CC", "D8BE82")),
    ]
    /// The presets in the order pickers list them: light ones, then dark.
    static let appearanceGroups: [(title: String, themes: [PotionTheme])] = [
        ("Light", presets.filter { !$0.isDark }), ("Dark", presets.filter(\.isDark)),
    ]
    /// Every preset's font pairing, in alphabetical order.
    static let fontSets: [ThemeFonts] = Array(Set(presets.map(\.fonts))).sorted { $0.name < $1.name }

    static func preset(id: String) -> PotionTheme? { presets.first { $0.id == id } }
    /// The theme Potion starts with, and falls back to.
    static var standard: PotionTheme { presets[0] }
    static let fontSizeRange: ClosedRange<Double> = 13...22
    static let lineHeightRange: ClosedRange<Double> = 1.3...2

    var isDark: Bool { colors.isDark }
    var hasName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// A new custom theme mixed from this one.
    func customCopy() -> PotionTheme {
        var copy = self
        copy.id = UUID().uuidString
        copy.name = "My \(name)"
        copy.isCustom = true
        return copy
    }
    /// Presets as they're defined now, so saved selections pick up changes to them.
    var latest: PotionTheme { isCustom ? self : Self.preset(id: id) ?? Self.standard }
    var validated: PotionTheme {
        var copy = self
        let fallback = Self.standard
        for (_, key) in ThemeColors.fields {
            copy.colors[keyPath: key] = Self.cleanHex(copy.colors[keyPath: key]) ?? fallback.colors[keyPath: key]
        }
        for key in [\ThemeFonts.heading, \.body] where FontCatalog.url(for: copy.fonts[keyPath: key]) == nil {
            copy.fonts[keyPath: key] = fallback.fonts[keyPath: key]
        }
        copy.fontSize = copy.fontSize.isFinite ? copy.fontSize.clamped(to: Self.fontSizeRange) : fallback.fontSize
        copy.lineHeight = copy.lineHeight.isFinite ? copy.lineHeight.clamped(to: Self.lineHeightRange) : fallback.lineHeight
        copy.name = String(copy.name.prefix(60))
        return copy
    }

    static func cleanHex(_ value: String) -> String? {
        let hex = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard hex.count == 6, hex.allSatisfy({ $0.isHexDigit && $0.isASCII }) else { return nil }
        return hex.uppercased()
    }
}

@MainActor final class ThemeStore: ObservableObject {
    @Published var selected: PotionTheme { didSet { persist() } }
    @Published var customs: [PotionTheme] { didSet { persist() } }
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: Self.enabledKey) } }
    private let defaults: UserDefaults
    private static let archiveKey = "potion.themes.v2"
    private static let enabledKey = "themeEnabled"
    private struct Archive: Codable { var selected: PotionTheme; var customs: [PotionTheme] }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let archive = defaults.data(forKey: Self.archiveKey).flatMap { try? JSONDecoder().decode(Archive.self, from: $0) }
        selected = archive?.selected.latest.validated ?? .standard
        customs = archive?.customs.map(\.validated) ?? []
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }
    /// Selection identifier for Notion's own styling, which sits alongside the themes in pickers.
    nonisolated static let originalID = "original"
    var all: [PotionTheme] { PotionTheme.presets + customs }
    /// Every theme a picker offers, Notion's own styling first.
    var choices: [PotionTheme] { [PotionTheme.original] + all }
    var activeID: String {
        get { enabled ? selected.id : Self.originalID }
        set { activate(newValue) }
    }
    func activate(_ id: String) {
        if id == Self.originalID { enabled = false }
        else if let theme = all.first(where: { $0.id == id }) { select(theme) }
    }
    func select(_ theme: PotionTheme) { selected = theme; enabled = true }
    func save(_ theme: PotionTheme) {
        var saved = theme.validated
        if !saved.isCustom { saved.id = UUID().uuidString }
        saved.isCustom = true
        if !saved.hasName { saved.name = "My theme" }
        if let index = customs.firstIndex(where: { $0.id == saved.id }) { customs[index] = saved }
        else { customs.append(saved) }
        select(saved)
    }
    func delete(_ theme: PotionTheme) {
        customs.removeAll { $0.id == theme.id }
        if selected.id == theme.id { selected = .standard }
    }
    private func persist() {
        guard let data = try? JSONEncoder().encode(Archive(selected: selected, customs: customs)) else { return }
        defaults.set(data, forKey: Self.archiveKey)
    }
}

enum FontCatalog {
    /// The bundled font files, by the family name each one declares.
    static let files: [String: URL] = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        return Dictionary(urls.compactMap { url -> (String, URL)? in
            guard let descriptor = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first,
                  let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String else { return nil }
            return (family, url)
        }, uniquingKeysWith: { first, _ in first })
    }()
    static let families = files.keys.sorted()
    static func register() { CTFontManagerRegisterFontURLs(Array(files.values) as CFArray, .process, true, nil) }
    static func url(for family: String) -> URL? { files[family] }
}

extension NSColor {
    convenience init(hex: String) {
        let value = UInt32(PotionTheme.cleanHex(hex) ?? "000000", radix: 16) ?? 0
        self.init(srgbRed: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, alpha: 1)
    }
    var hex: String {
        let color = usingColorSpace(.sRGB) ?? self
        return String(format: "%02X%02X%02X", Int((color.redComponent * 255).rounded()), Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
    }
}
extension Color { init(hex: String) { self.init(nsColor: NSColor(hex: hex)) } }
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(range.upperBound, max(range.lowerBound, self)) }
}
