import SwiftUI

struct ThemeEditor: View {
    let original: PotionTheme
    @ObservedObject var workspace: Workspace
    @ObservedObject var store: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PotionTheme
    @State private var saved = false

    init(original: PotionTheme, workspace: Workspace, store: ThemeStore) {
        self.original = original
        self.workspace = workspace
        self.store = store
        var theme = original
        if !theme.isCustom { theme.name = "My \(theme.name)" }
        _draft = State(initialValue: theme)
    }
    private var valid: Bool {
        [draft.background, draft.surface, draft.text, draft.accent].allSatisfy { PotionTheme.cleanHex($0) != nil }
        && !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("A mix of your own.").font(.custom("Lora", size: 28))
                    Text("Small details. A space that feels entirely yours.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "slider.horizontal.3").font(.system(size: 24)).foregroundStyle(Color(hex: "63724D"))
            }
            HStack(alignment: .top, spacing: 30) {
                VStack(alignment: .leading, spacing: 18) {
                    field("THEME NAME") { TextField("My theme", text: $draft.name).textFieldStyle(.roundedBorder) }
                    field("HEADING FONT") { Picker("Heading font", selection: $draft.headingFont) { ForEach(FontCatalog.families, id: \.self) { Text($0).tag($0) } }.labelsHidden() }
                    field("BODY FONT") { Picker("Body font", selection: $draft.bodyFont) { ForEach(FontCatalog.families, id: \.self) { Text($0).tag($0) } }.labelsHidden() }
                    field("TEXT SIZE  ·  \(Int(draft.fontSize)) PX") { Slider(value: $draft.fontSize, in: 13...22, step: 1).accessibilityLabel("Text size") }
                    field("LINE SPACING  ·  \(draft.lineHeight.formatted(.number.precision(.fractionLength(2))))") { Slider(value: $draft.lineHeight, in: 1.3...2, step: 0.05).accessibilityLabel("Line spacing") }
                }.frame(width: 225)
                VStack(alignment: .leading, spacing: 17) {
                    Text("YOUR PALETTE").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
                    ColorField(title: "Page", hex: $draft.background)
                    ColorField(title: "Surfaces", hex: $draft.surface)
                    ColorField(title: "Text", hex: $draft.text)
                    ColorField(title: "Accent & links", hex: $draft.accent)
                    Text("Use the color well or enter a six-digit hex color.").font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(width: 235)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Room for your next good idea.").font(.custom(draft.headingFont, size: 27))
                Text("A favorite font. A softer shade. Sometimes a little change makes all the difference.")
                    .font(.custom(draft.bodyFont, size: draft.fontSize)).lineSpacing((draft.lineHeight - 1) * draft.fontSize / 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Make yourself at home ↗").font(.custom(draft.bodyFont, size: 12)).foregroundStyle(Color(hex: draft.accent))
            }.foregroundStyle(Color(hex: draft.text)).padding(23).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: draft.background), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: draft.surface), lineWidth: 2))
            HStack {
                Button("Reset Changes") { draft = original; if !original.isCustom { draft.name = "My \(original.name)" } }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save Theme") {
                    store.save(draft)
                    saved = true
                    workspace.apply(store.selected, enabled: store.enabled)
                    dismiss()
                }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(Color(hex: "63724D")).disabled(!valid)
            }
        }.padding(30).frame(width: 580).background(Color(hex: "F8F8F4"))
            .onAppear { workspace.apply(draft, enabled: true) }
            .onChange(of: draft) { _, theme in if valid { workspace.apply(theme, enabled: true) } }
            .onDisappear { if !saved { workspace.apply(store.selected, enabled: store.enabled) } }
    }
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
            content().frame(maxWidth: .infinity)
        }
    }
}

private struct ColorField: View {
    let title: String
    @Binding var hex: String
    private var color: Binding<Color> {
        Binding(get: { Color(hex: hex) }, set: { hex = NSColor($0).hex })
    }
    var body: some View {
        HStack {
            ColorPicker(title, selection: color, supportsOpacity: false).labelsHidden()
            Text(title).font(.system(size: 11))
            Spacer()
            TextField("Hex", text: $hex).font(.system(size: 10, design: .monospaced)).textFieldStyle(.roundedBorder).frame(width: 72)
                .accessibilityLabel("\(title) hex color")
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(PotionTheme.cleanHex(hex) == nil ? Color.red : Color.clear))
        }
    }
}
