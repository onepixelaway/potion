import SwiftUI

private let ink = Color(hex: "353A32")
private let muted = Color(hex: "85877D")
private let olive = Color(hex: "63724D")
private let chrome = Color(hex: "F8F8F4")

struct ContentView: View {
    @ObservedObject var store: ThemeStore
    @ObservedObject var workspace: Workspace
    @State private var editorTheme: PotionTheme?
    @State private var showingAbout = false
    @State private var showsThemes = true

    var body: some View {
        HStack(spacing: 0) {
            if showsThemes {
                sidebar.frame(width: 300)
                Rectangle().fill(ink.opacity(0.1)).frame(width: 1)
            }
            VStack(spacing: 0) {
                toolbar
                Rectangle().fill(ink.opacity(0.1)).frame(height: 1)
                ZStack(alignment: .top) {
                    Color(hex: store.selected.background)
                    WebWorkspace(workspace: workspace)
                    if workspace.isLoading { ProgressView().controlSize(.small).padding(12).background(.regularMaterial, in: Capsule()).padding(.top, 12) }
                    if let error = workspace.error { errorView(error) }
                }
                bottomBar
            }
        }
        .background(chrome)
        .foregroundStyle(ink)
        .preferredColorScheme(.light)
        .sheet(item: $editorTheme) { theme in
            ThemeEditor(original: theme, workspace: workspace, store: store)
        }
        .alert("A little magic for your workspace.", isPresented: $showingAbout) {
            Button("Lovely", role: .cancel) {}
        } message: {
            Text("Potion is an independent Mac wrapper for Notion. Your account stays in Notion; your themes stay on this Mac. Fonts are bundled from Google Fonts under the SIL Open Font License.\n\nIf an identity provider restricts embedded sign-in, choose Notion’s email sign-in option. Potion is not affiliated with Notion.")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(olive).frame(width: 42, height: 45)
                    Image(systemName: "flask.fill").font(.system(size: 22, weight: .medium)).foregroundStyle(Color(hex: "F6F5E7"))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("potion").font(.custom("Lora", size: 29)).tracking(-1.2)
                    Text("A NOTION OF YOUR OWN").font(.system(size: 8, weight: .medium)).tracking(1.5).foregroundStyle(muted)
                }
                Spacer()
            }.padding(.top, 45).padding(.bottom, 28)
            HStack {
                Text("Your workspace,\nyour kind of calm.").font(.custom("Lora", size: 24)).lineSpacing(2).tracking(-0.6)
                Spacer()
            }
            Text("A fresh perspective is a theme away.").font(.system(size: 11)).foregroundStyle(muted).padding(.top, 10).padding(.bottom, 27)
            HStack {
                sectionLabel("THE COLLECTION")
                Spacer()
                Text("06").font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
            }.padding(.bottom, 12)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(PotionTheme.presets) { theme in themeCard(theme) }
                    if !store.customs.isEmpty {
                        HStack { sectionLabel("MADE BY YOU"); Spacer() }.padding(.top, 15).padding(.bottom, 2)
                        ForEach(store.customs) { theme in
                            themeCard(theme).contextMenu {
                                Button("Edit Theme") { editorTheme = theme }
                                Button("Delete Theme", role: .destructive) { store.delete(theme) }
                            }
                        }
                    }
                }.padding(2)
            }.scrollIndicators(.hidden)
            Button {
                var copy = store.selected
                copy.id = UUID().uuidString
                copy.name = "My \(copy.name)"
                copy.isCustom = true
                editorTheme = copy
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 13))
                    Text("Mix your own theme").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "plus").font(.system(size: 11))
                }.padding(14).background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }.buttonStyle(.plain).padding(.top, 14)
            HStack(spacing: 6) {
                Circle().fill(olive).frame(width: 5, height: 5)
                Text("A little more you.").font(.system(size: 10)).foregroundStyle(muted)
                Spacer()
                Button { showingAbout = true } label: { Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(muted) }.buttonStyle(.plain).help("About Potion")
            }.padding(.top, 21).padding(.bottom, 20)
        }.padding(.horizontal, 23)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .semibold)).tracking(1.7).foregroundStyle(muted)
    }
    private func themeCard(_ theme: PotionTheme) -> some View {
        let selected = store.selected.id == theme.id
        return Button { store.select(theme) } label: {
            HStack(spacing: 12) {
                Text("Aa").font(.custom(theme.headingFont, size: 27)).tracking(-1.5)
                    .foregroundStyle(Color(hex: theme.text)).frame(width: 52, height: 54)
                    .background(Color(hex: theme.surface), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(theme.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 4)
                        if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(olive) }
                    }
                    Text("\(theme.headingFont) + \(theme.bodyFont)").font(.system(size: 8.5)).foregroundStyle(muted).lineLimit(1)
                    HStack(spacing: 4) {
                        ForEach([theme.background, theme.surface, theme.text, theme.accent], id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 10, height: 10).overlay(Circle().strokeBorder(ink.opacity(0.09), lineWidth: 0.5))
                        }
                    }
                }
            }.padding(10).background(selected ? Color.white : Color.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? olive.opacity(0.65) : ink.opacity(0.07), lineWidth: selected ? 1.3 : 1))
        }.buttonStyle(.plain).accessibilityLabel("\(theme.name) theme, \(theme.headingFont) and \(theme.bodyFont)").accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var toolbar: some View {
        HStack(spacing: 15) {
            Button { showsThemes.toggle() } label: { Image(systemName: "sidebar.left") }
                .buttonStyle(.plain).foregroundStyle(muted)
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .help("Show or hide themes (⇧⌘T)")
            HStack(spacing: 14) {
                Button { workspace.webView.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!workspace.canGoBack).help("Back")
                Button { workspace.webView.goForward() } label: { Image(systemName: "chevron.right") }.disabled(!workspace.canGoForward).help("Forward")
                Button { workspace.reload() } label: { Image(systemName: "arrow.clockwise") }.help("Reload (⌘R)")
            }.font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(muted)
            Rectangle().fill(ink.opacity(0.12)).frame(width: 1, height: 18)
            Image(systemName: workspace.isPreview ? "sparkles" : "lock.fill").font(.system(size: 11)).foregroundStyle(olive)
            Text(workspace.isPreview ? "The fitting room" : "Your Notion workspace").font(.system(size: 12, weight: .medium))
            Spacer()
            if !workspace.isPreview {
                Button("Preview") { workspace.showPreview() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(muted)
            }
            Button { workspace.openNotion() } label: {
                HStack(spacing: 8) { Text("Open Notion"); Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold)) }
                    .font(.system(size: 11, weight: .medium)).padding(.horizontal, 14).padding(.vertical, 9)
                    .foregroundStyle(.white).background(olive, in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain).help("Open your Notion workspace (⌘O)")
        }.padding(.horizontal, 25).frame(height: 70)
    }
    private var bottomBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.lefthalf.filled").foregroundStyle(olive)
            Text(store.enabled ? store.selected.name : "Original Notion").fontWeight(.medium)
            Text("·").foregroundStyle(muted)
            Text(store.enabled ? store.selected.subtitle : "Potion styling is paused.").foregroundStyle(muted).lineLimit(1)
            Spacer()
            Button("Customize") { editorTheme = store.selected }.buttonStyle(.plain).foregroundStyle(olive)
            Divider().frame(height: 13).padding(.horizontal, 4)
            Toggle("Theme", isOn: $store.enabled).toggleStyle(.switch).controlSize(.mini).tint(olive)
        }.font(.system(size: 10)).padding(.horizontal, 26).frame(height: 47)
            .background(chrome).overlay(alignment: .top) { Rectangle().fill(ink.opacity(0.1)).frame(height: 1) }
    }
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(olive)
            Text("A small interruption").font(.custom("Lora", size: 26))
            Text(message).font(.system(size: 12)).foregroundStyle(muted).multilineTextAlignment(.center).frame(maxWidth: 400)
            HStack {
                Button("Try Again") { workspace.reload() }
                Button("Theme Preview") { workspace.showPreview() }
                Button("Open in Browser") { workspace.openInBrowser() }
            }
        }.padding(35).background(chrome, in: RoundedRectangle(cornerRadius: 15)).shadow(color: .black.opacity(0.08), radius: 30).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
