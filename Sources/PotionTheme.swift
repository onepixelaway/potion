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

    var isDark: Bool { NSColor(hex: background).brightnessComponent < 0.45 }
    var validated: PotionTheme {
        var copy = self
        let fallback = Self.presets[0]
        for key in [\PotionTheme.background, \.surface, \.text, \.accent] {
            copy[keyPath: key] = Self.cleanHex(copy[keyPath: key]) ?? fallback[keyPath: key]
        }
        if !FontCatalog.families.contains(copy.headingFont) { copy.headingFont = fallback.headingFont }
        if !FontCatalog.families.contains(copy.bodyFont) { copy.bodyFont = fallback.bodyFont }
        copy.fontSize = copy.fontSize.isFinite ? min(22, max(13, copy.fontSize)) : 16
        copy.lineHeight = copy.lineHeight.isFinite ? min(2, max(1.3, copy.lineHeight)) : 1.65
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
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "themeEnabled") } }
    private let defaults: UserDefaults
    private struct Archive: Codable { var selected: PotionTheme; var customs: [PotionTheme] }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let archive = defaults.data(forKey: "potion.themes.v1").flatMap { try? JSONDecoder().decode(Archive.self, from: $0) }
        selected = archive?.selected.validated ?? PotionTheme.presets[0]
        customs = archive?.customs.map(\.validated) ?? []
        enabled = defaults.object(forKey: "themeEnabled") as? Bool ?? true
    }
    func select(_ theme: PotionTheme) { selected = theme; enabled = true }
    func save(_ theme: PotionTheme) {
        var saved = theme.validated
        if !saved.isCustom { saved.id = UUID().uuidString }
        saved.isCustom = true
        if saved.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { saved.name = "My theme" }
        if let index = customs.firstIndex(where: { $0.id == saved.id }) { customs[index] = saved }
        else { customs.append(saved) }
        select(saved)
    }
    func delete(_ theme: PotionTheme) {
        customs.removeAll { $0.id == theme.id }
        if selected.id == theme.id { selected = PotionTheme.presets[0] }
    }
    private func persist() {
        guard let data = try? JSONEncoder().encode(Archive(selected: selected, customs: customs)) else { return }
        defaults.set(data, forKey: "potion.themes.v1")
    }
}

enum FontCatalog {
    static let families = ["DM Sans", "DM Serif Display", "Lora", "Manrope", "Source Sans 3", "Space Grotesk"]
    static var urls: [URL] { Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] }
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
