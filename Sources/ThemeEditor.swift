import SwiftUI

/// The theme editor in the Appearance panel. A theme is a color set and a font pairing, each chosen from a menu of
/// every preset's; the pencil beside either opens its individual settings to make a variant of your own. Edits
/// preview live on every tab in the window (through `AppearanceState.preview`); Save keeps them, and Cancel or
/// closing the editor shows the saved theme again.
struct ThemeEditor: View {
    let original: PotionTheme
    @ObservedObject var store: ThemeStore
    @ObservedObject var appearance: AppearanceState
    @State private var draft: PotionTheme
    @State private var editsColors: Bool
    @State private var editsFonts: Bool

    init(original: PotionTheme, store: ThemeStore, appearance: AppearanceState) {
        self.original = original
        self.store = store
        self.appearance = appearance
        _draft = State(initialValue: original)
        // A theme that already has its own colors or fonts opens with them showing.
        _editsColors = State(initialValue: !original.colors.isPreset)
        _editsFonts = State(initialValue: !original.fonts.isPreset)
    }
    private var isNew: Bool { !store.customs.contains { $0.id == original.id } }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $draft.name)
            } header: {
                Text(isNew ? "New Theme" : "Edit Theme").font(.title3.bold()).foregroundStyle(.primary)
            }
            Section {
                setRow(isEditing: $editsColors, help: "Adjust each color") {
                    Picker("Colors", selection: $draft.colors) {
                        ForEach(PotionTheme.appearanceGroups, id: \.title) { group in
                            Section(group.title) {
                                ForEach(group.themes) { theme in
                                    Label { Text(theme.name) } icon: { Image(nsImage: theme.colors.swatch) }.tag(theme.colors)
                                }
                            }
                        }
                        if !draft.colors.isPreset {
                            Divider()
                            Label { Text("Custom") } icon: { Image(nsImage: draft.colors.swatch) }.tag(draft.colors)
                        }
                    }
                }
                if editsColors {
                    colorPicker("Page", \.background)
                    colorPicker("Sidebar and Surfaces", \.surface)
                    colorPicker("Page Title", \.title)
                    colorPicker("Headings", \.heading)
                    colorPicker("Text", \.text)
                    colorPicker("Accent and Links", \.accent)
                }
            }
            Section {
                setRow(isEditing: $editsFonts, help: "Adjust fonts, size and spacing") {
                    Picker("Fonts", selection: $draft.fonts) {
                        ForEach(PotionTheme.fontSets, id: \.self) { Text($0.name).tag($0) }
                        if !draft.fonts.isPreset {
                            Divider()
                            Text("Custom").tag(draft.fonts)
                        }
                    }
                }
                if editsFonts {
                    fontPicker("Title and Headings", selection: $draft.fonts.heading)
                    fontPicker("Body", selection: $draft.fonts.body)
                    slider("Text Size", value: $draft.fontSize, in: PotionTheme.fontSizeRange, step: 1, label: "\(Int(draft.fontSize)) pt")
                    slider("Line Spacing", value: $draft.lineHeight, in: PotionTheme.lineHeightRange, step: 0.05,
                           label: draft.lineHeight.formatted(.number.precision(.fractionLength(2))))
                }
            }
            Section("Sample") { sample }
        }
        .formStyle(.grouped)
        .bottomBar {
            HStack {
                Button("Revert") { draft = original }
                    .disabled(draft == original)
                Spacer()
                Button("Cancel") { appearance.editing = nil }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    store.save(draft)
                    appearance.editing = nil
                }
                .prominentStyle()
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.hasName)
            }
            .padding(16)
        }
        .onChange(of: draft, initial: true) { _, theme in appearance.preview = theme }
        // Choosing a different theme (from the Theme menu) abandons the edit.
        .onChange(of: store.activeID) { _, _ in appearance.editing = nil }
    }

    /// A color set or font pairing menu, with the pencil that shows its individual settings.
    private func setRow(isEditing: Binding<Bool>, help: String, @ViewBuilder picker: () -> some View) -> some View {
        HStack(spacing: 8) {
            picker()
            Button {
                withAnimation(.snappy) { isEditing.wrappedValue.toggle() }
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(isEditing.wrappedValue ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .background(isEditing.wrappedValue ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .circle)
            }
            .buttonStyle(.borderless)
            .help(help)
            .accessibilityLabel(help)
        }
    }

    private var sample: some View {
        let colors = draft.colors
        return VStack(alignment: .leading, spacing: 8) {
            Text("Room for your next idea").font(.custom(draft.fonts.heading, size: 24)).foregroundStyle(Color(hex: colors.title))
            Text("A softer kind of focus").font(.custom(draft.fonts.heading, size: 17)).foregroundStyle(Color(hex: colors.heading))
            Text("A favorite font. A softer shade. Sometimes a small change makes all the difference.")
                .font(.custom(draft.fonts.body, size: draft.fontSize))
                .lineSpacing((draft.lineHeight - 1) * draft.fontSize / 2)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color(hex: colors.text))
            Text("Make yourself at home").font(.custom(draft.fonts.body, size: 13)).foregroundStyle(Color(hex: colors.accent)).underline()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: colors.background), in: .rect(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: colors.surface), lineWidth: 2) }
    }

    private func fontPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(FontCatalog.families, id: \.self) { Text($0).tag($0) }
        }
    }
    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, label: String) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range, step: step).accessibilityLabel(title)
                Text(label).monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
            }
        }
    }
    private func colorPicker(_ title: String, _ key: WritableKeyPath<ThemeColors, String>) -> some View {
        ColorPicker(title, selection: Binding(get: { Color(hex: draft.colors[keyPath: key]) },
                                              set: { draft.colors[keyPath: key] = NSColor($0).hex }),
                    supportsOpacity: false)
    }
}
