import AppKit
import SwiftUI
import CoreText

struct PotionTheme: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var subtitle: String
    var headingFont: String
    var bodyFont: String
    var background: String
    var surface: String
    var text: String
    var accent: String
    var fontSize: Double = 16
    var lineHeight: Double = 1.65
    var isCustom = false

    static let presets: [PotionTheme] = [
        .init(id: "paper", name: "Paper", subtitle: "A little room to think.", headingFont: "Lora", bodyFont: "DM Sans", background: "F8F5EF", surface: "EEEAE2", text: "353A32", accent: "65754F"),
        .init(id: "botanical", name: "Botanical", subtitle: "Fresh ideas take root.", headingFont: "DM Serif Display", bodyFont: "Manrope", background: "EDF2EB", surface: "DFE8DC", text: "293F35", accent: "40705B"),
        .init(id: "lavender", name: "Lavender", subtitle: "Find your softer focus.", headingFont: "Lora", bodyFont: "Source Sans 3", background: "F4F0F9", surface: "E9E1F2", text: "443951", accent: "82639F"),
        .init(id: "clay", name: "Clay", subtitle: "For beautifully messy ideas.", headingFont: "DM Serif Display", bodyFont: "DM Sans", background: "FBF0E8", surface: "F0DFD3", text: "4A342D", accent: "AB6048"),
        .init(id: "midnight", name: "Midnight", subtitle: "Make space for the late shift.", headingFont: "Space Grotesk", bodyFont: "DM Sans", background: "20252C", surface: "2B323C", text: "E7E9EC", accent: "A9C2EB"),
        .init(id: "mono", name: "Studio", subtitle: "Less noise. More clarity.", headingFont: "Space Grotesk", bodyFont: "Manrope", background: "F5F5F3", surface: "E8E8E5", text: "303330", accent: "56665F")
    ]

    /// The theme Potion starts with, and falls back to.
    static var standard: PotionTheme { presets[0] }
    static let fontSizeRange: ClosedRange<Double> = 13...22
    static let lineHeightRange: ClosedRange<Double> = 1.3...2

    var isDark: Bool { NSColor(hex: background).brightnessComponent < 0.45 }
    var hasName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// A new custom theme mixed from this one.
    func customCopy() -> PotionTheme {
        var copy = self
        copy.id = UUID().uuidString
        copy.name = "My \(name)"
        copy.isCustom = true
        return copy
    }
    var validated: PotionTheme {
        var copy = self
        let fallback = Self.standard
        for key in [\PotionTheme.background, \.surface, \.text, \.accent] {
            copy[keyPath: key] = Self.cleanHex(copy[keyPath: key]) ?? fallback[keyPath: key]
        }
        if !FontCatalog.families.contains(copy.headingFont) { copy.headingFont = fallback.headingFont }
        if !FontCatalog.families.contains(copy.bodyFont) { copy.bodyFont = fallback.bodyFont }
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
    private static let archiveKey = "potion.themes.v1"
    private static let enabledKey = "themeEnabled"
    private struct Archive: Codable { var selected: PotionTheme; var customs: [PotionTheme] }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let archive = defaults.data(forKey: Self.archiveKey).flatMap { try? JSONDecoder().decode(Archive.self, from: $0) }
        selected = archive?.selected.validated ?? .standard
        customs = archive?.customs.map(\.validated) ?? []
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }
    /// Selection identifier for Notion's own styling, which sits alongside the themes in pickers.
    static let originalID = "original"
    var all: [PotionTheme] { PotionTheme.presets + customs }
    /// Every theme a picker offers, Notion's own styling first.
    var choices: [PotionTheme] { [PotionTheme.original] + all }
    var activeID: String { enabled ? selected.id : Self.originalID }
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
    static let families = ["DM Sans", "DM Serif Display", "Lora", "Manrope", "Source Sans 3", "Space Grotesk"]
    static let urls: [URL] = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
    static func register() { urls.forEach { CTFontManagerRegisterFontsForURL($0 as CFURL, .process, nil) } }
    static func url(for family: String) -> URL? {
        let prefix = family.replacingOccurrences(of: " ", with: "").lowercased()
        return urls.first { $0.lastPathComponent.lowercased().hasPrefix(prefix) }
    }
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
