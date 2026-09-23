import SwiftUI

/// The theme editor in the Appearance panel. Edits preview live on every tab; Save keeps them and Cancel restores the saved theme.
struct ThemeEditor: View {
    let original: PotionTheme
    @ObservedObject var tabs: BrowserTabs
    @ObservedObject var store: ThemeStore
    @ObservedObject var appearance: AppearanceState
    @State private var draft: PotionTheme
    @State private var saved = false
    private let initial: PotionTheme

    init(original: PotionTheme, tabs: BrowserTabs, store: ThemeStore, appearance: AppearanceState) {
        self.original = original
        self.tabs = tabs
        self.store = store
        self.appearance = appearance
        var theme = original
        if !theme.isCustom { theme.name = "My \(theme.name)" }
        initial = theme
        _draft = State(initialValue: theme)
    }
    private var isNew: Bool { !store.customs.contains { $0.id == original.id } }
    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $draft.name)
            } header: {
                Text(isNew ? "New Theme" : "Edit Theme").font(.title3.bold()).foregroundStyle(.primary)
            }
            Section("Typography") {
                fontPicker("Headings", selection: $draft.headingFont)
                fontPicker("Body", selection: $draft.bodyFont)
                LabeledContent("Text Size") {
                    HStack {
                        Slider(value: $draft.fontSize, in: 13...22, step: 1).accessibilityLabel("Text size")
                        Text("\(Int(draft.fontSize)) pt").monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                    }
                }
                LabeledContent("Line Spacing") {
                    HStack {
                        Slider(value: $draft.lineHeight, in: 1.3...2, step: 0.05).accessibilityLabel("Line spacing")
                        Text(draft.lineHeight.formatted(.number.precision(.fractionLength(2)))).monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                    }
                }
            }
            Section("Colors") {
                colorPicker("Page", hex: $draft.background)
                colorPicker("Surfaces", hex: $draft.surface)
                colorPicker("Text", hex: $draft.text)
                colorPicker("Accent and Links", hex: $draft.accent)
            }
            Section("Sample") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room for your next idea.").font(.custom(draft.headingFont, size: 22))
                    Text("A favorite font. A softer shade. Sometimes a small change makes all the difference.")
                        .font(.custom(draft.bodyFont, size: draft.fontSize))
                        .lineSpacing((draft.lineHeight - 1) * draft.fontSize / 2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Make yourself at home").font(.custom(draft.bodyFont, size: 13)).foregroundStyle(Color(hex: draft.accent)).underline()
                }
                .foregroundStyle(Color(hex: draft.text))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: draft.background), in: .rect(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: draft.surface), lineWidth: 2) }
            }
        }
        .formStyle(.grouped)
        .bottomBar {
            HStack {
                Button("Revert") { draft = initial }
                    .disabled(draft == initial)
                Spacer()
                Button("Cancel") { appearance.editing = nil }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    saved = true
                    store.save(draft)
                    appearance.editing = nil
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .onAppear { tabs.preview(draft) }
        .onChange(of: draft) { _, theme in tabs.preview(theme) }
        // Choosing a different theme (from the Theme menu) abandons the edit.
        .onChange(of: store.activeID) { _, _ in if !saved { appearance.editing = nil } }
        .onDisappear { if !saved { tabs.restoreStyling() } }
    }

    private func fontPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(FontCatalog.families, id: \.self) { Text($0).tag($0) }
        }
    }
    private func colorPicker(_ title: String, hex: Binding<String>) -> some View {
        ColorPicker(title, selection: Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = NSColor($0).hex }),
                    supportsOpacity: false)
    }
}
