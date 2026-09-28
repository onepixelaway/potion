import AppKit

enum NavigationDecision: Equatable { case allow, openExternally, cancel }

enum NavigationPolicy {
    static let notionDomains = ["notion.so", "notion.site", "notion.com"]
    static let authenticationHosts: Set<String> = [
        "accounts.google.com", "appleid.apple.com", "idmsa.apple.com",
        "login.microsoftonline.com", "login.microsoft.com", "login.live.com", "account.live.com",
    ]
    /// First path components of Notion pages that exist before or during sign-in.
    private static let signInPaths: Set<String> = ["", "login", "signup", "logout", "onboarding", "sso", "loginwithemail", "verifynopopupblockerhtmlandredirect"]
    /// Hosts of the Notion app itself, as opposed to notion.com's marketing and help pages or published notion.site pages.
    private static func isAppHost(_ host: String) -> Bool { host == "app.notion.com" || host == "notion.so" || host.hasSuffix(".notion.so") }

    private static func httpsHost(_ url: URL) -> String? { url.scheme == "https" ? url.host?.lowercased() : nil }
    private static func firstPathComponent(_ url: URL) -> String { url.pathComponents.dropFirst().first?.lowercased() ?? "" }

    static func isNotion(_ url: URL) -> Bool {
        guard let host = httpsHost(url) else { return false }
        return notionDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
    static func isAuthentication(_ url: URL) -> Bool { httpsHost(url).map(authenticationHosts.contains) ?? false }
    /// A Notion page title without the “| Notion” suffix, for window tabs.
    static func pageTitle(_ title: String) -> String {
        var result = title.trimmingCharacters(in: .whitespaces)
        for suffix in [" | Notion", " – Notion", " - Notion"] where result.hasSuffix(suffix) { result.removeLast(suffix.count) }
        return result.isEmpty ? "Notion" : result
    }
    static func withoutQuery(_ url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }
    static func isBlank(_ url: URL) -> Bool { url.absoluteString == "about:blank" }
    /// Pages that always load in Potion: Notion, the identity providers it signs in with, and blank pages.
    static func isTrusted(_ url: URL) -> Bool { isBlank(url) || isNotion(url) || isAuthentication(url) }
    static func canOpenExternally(_ url: URL) -> Bool { ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") }
    /// Opens a link in the person's browser or mail app, if it's a kind those can open.
    static func openExternally(_ url: URL) { if canOpenExternally(url) { NSWorkspace.shared.open(url) } }

    /// True for pages of a signed-in workspace, which is how Potion knows sign-in has finished.
    static func isWorkspacePage(_ url: URL) -> Bool {
        guard let host = httpsHost(url), isAppHost(host) else { return false }
        let first = firstPathComponent(url)
        return !signInPaths.contains(first) && !first.contains("popup") && !first.contains("callback")
    }
    /// Workspace pages worth reopening later. Notion's `/note/…` addresses are short-lived and can't be reopened.
    static func isRestorable(_ url: URL) -> Bool {
        isWorkspacePage(url) && firstPathComponent(url) != "note"
    }
    /// Notion opens OAuth sign-in through a sized popup on its own domain, which must stay a real window.
    static func isSignInPopup(_ url: URL, hasWindowSize: Bool) -> Bool {
        let path = url.path.lowercased()
        return hasWindowSize || path.contains("popup")
    }

    /// Main-window navigations. Notion and sign-in pages load in place; links people click to other sites open
    /// in their browser. Redirects away from Notion (enterprise SSO) stay in place so sign-in can complete.
    static func decision(for url: URL, isLinkClick: Bool, from current: URL?) -> NavigationDecision {
        if isTrusted(url) { return .allow }
        guard httpsHost(url) != nil else { return canOpenExternally(url) ? .openExternally : .cancel }
        let leavingNotion = current.map(isNotion) ?? true
        return isLinkClick && leavingNotion ? .openExternally : .allow
    }
    /// Sign-in popup navigations. The first page must belong to Notion or a known identity provider; after that the
    /// provider may redirect wherever its sign-in flow needs to go.
    static func popupDecision(for url: URL, from current: URL?) -> NavigationDecision {
        if isTrusted(url) { return .allow }
        let started = current.map { !isBlank($0) } ?? false
        if started && httpsHost(url) != nil { return .allow }
        return canOpenExternally(url) ? .openExternally : .cancel
    }
}
