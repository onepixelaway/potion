import SwiftUI

/// Where the person is in Potion, shared by every window: first-run onboarding (welcome → sign in) or the workspace.
@MainActor final class AppFlow: ObservableObject {
    enum Stage { case welcome, signIn, ready }

    @Published private(set) var stage: Stage
    private let windows = NSHashTable<NSWindow>.weakObjects()
    private let defaults: UserDefaults
    private static let completedKey = "potion.onboardingCompleted"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        stage = defaults.bool(forKey: Self.completedKey) ? .ready : .welcome
    }

    var isOnboarding: Bool { stage != .ready }

    func go(to stage: Stage) {
        withAnimation(.smooth(duration: 0.35)) { self.stage = stage }
    }
    func signInChanged(_ signedIn: Bool) {
        if signedIn && stage == .signIn { completeOnboarding() }
    }
    private func completeOnboarding() {
        defaults.set(true, forKey: Self.completedKey)
        go(to: .ready)
    }

    func register(_ window: NSWindow) { windows.add(window) }

    func requestSignOut() {
        let window = NSApp.orderedWindows.first { windows.contains($0) }
        let alert = NSAlert()
        alert.messageText = "Sign out of Notion?"
        alert.informativeText = "Potion will remove Notion’s cookies and website data from this Mac and close your other tabs. Your themes stay."
        alert.addButton(withTitle: "Sign Out").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        let signOut: () -> Void = { [weak self] in
            Task { @MainActor in
                await Workspace.removeWebsiteData()
                self?.didSignOut(keeping: window)
            }
        }
        if let window {
            alert.beginSheetModal(for: window) { if $0 == .alertFirstButtonReturn { signOut() } }
        } else if alert.runModal() == .alertFirstButtonReturn {
            signOut()
        }
    }
    /// Keeps one window open for signing back in and closes the rest.
    func didSignOut(keeping window: NSWindow?) {
        if let window {
            for other in windows.allObjects where other !== window { other.close() }
        }
        defaults.set(false, forKey: Self.completedKey)
        go(to: .signIn)
    }
}

/// A theme being edited: the theme it started from, the theme as it was when editing began, and the unsaved changes.
struct ThemeEdit: Equatable {
    let baseID: String
    let original: PotionTheme
    var draft: PotionTheme
}

/// Per-window state of the Appearance panel: the theme gallery, and the editor while a theme is being edited.
@MainActor final class AppearanceState: ObservableObject {
    @Published var isShown = false {
        didSet {
            guard !isShown else { return }
            isChoosingFirstTheme = false
            edit = nil
        }
    }
    /// True right after sign-in, while the panel invites the person to pick their first theme.
    @Published private(set) var isChoosingFirstTheme = false
    /// The theme open in the editor. Closing the panel ends the edit.
    @Published var edit: ThemeEdit?
    /// The editor's unsaved changes, shown on every tab in the window in place of the saved theme.
    var preview: PotionTheme? { edit?.draft }

    /// Opens the panel so the first thing people do in their workspace is pick a theme.
    func beginFirstThemeChoice() {
        isShown = true
        isChoosingFirstTheme = true
    }
    /// The first theme choice closes the panel after a moment, so the new look is seen settling in.
    func themeChosen() {
        guard isChoosingFirstTheme else { return }
        isChoosingFirstTheme = false
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.smooth) { isShown = false }
        }
    }
    func toggle() {
        withAnimation(.smooth) { isShown.toggle() }
    }
    /// Edits a custom theme in place, or a preset as a new custom theme.
    func customize(_ theme: PotionTheme) { begin(from: theme, as: theme.isCustom ? theme : theme.customCopy()) }
    func newTheme(from theme: PotionTheme) { begin(from: theme, as: theme.customCopy()) }
    private func begin(from theme: PotionTheme, as original: PotionTheme) {
        isShown = true
        edit = ThemeEdit(baseID: theme.id, original: original, draft: original)
    }
    func saveEdit(to store: ThemeStore) {
        guard let edit else { return }
        store.save(edit.draft)
        self.edit = nil
    }
    func cancelEdit() { edit = nil }
    /// Takes the editor's changes only while the edit lasts, so a control finishing after Cancel can't bring it back.
    func updateEdit(_ edit: ThemeEdit) {
        if self.edit != nil { self.edit = edit }
    }
    /// Choosing a theme other than the one being edited, from the Theme menu or Settings, abandons the edit.
    func activeThemeChanged(to id: String) {
        if let edit, edit.baseID != id { self.edit = nil }
    }
}
