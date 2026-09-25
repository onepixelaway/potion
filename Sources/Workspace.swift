import SwiftUI
import WebKit

/// A sign-in window a page opened with `window.open`, shown as a sheet.
struct AuthPopup: Identifiable {
    let webView: WKWebView
    var id: ObjectIdentifier { ObjectIdentifier(webView) }
}

/// One tab's Notion web view and the state its window shows. Observed per property, so a loading-progress tick
/// redraws only the views that read progress.
@MainActor @Observable final class Workspace: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, WKScriptMessageHandler {
    static let loginURL = URL(string: "https://app.notion.com/login")!
    static let homeURL = URL(string: "https://app.notion.com/")!
    /// The offline sample page. Used to verify theme rendering without a Notion account.
    static let previewURL = Bundle.main.url(forResource: "Preview", withExtension: "html")
    private static let lastURLKey = "potion.lastNotionURL"

    @ObservationIgnored let webView: WKWebView
    private(set) var isLoading = false
    private(set) var progress = 0.0
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var title = ""
    private(set) var url: URL?
    private(set) var isSignedIn = false
    var error: String?
    var authPopup: AuthPopup?
    /// Width of Notion's sidebar (0 when it's collapsed), so Potion's tab row starts at its edge.
    private(set) var sidebarWidth: CGFloat = 0
    /// Unread notifications in Notion's inbox.
    private(set) var inboxCount = 0
    /// Moves Notion's sidebar row into the title bar and makes room for Potion's tab row. Off during sign-in.
    @ObservationIgnored var usesWindowLayout = false {
        didSet {
            guard usesWindowLayout != oldValue else { return }
            scriptsOutdated = true
            run(ThemeInjection.layoutFlag(usesWindowLayout) + ThemeInjection.chromeRefresh)
        }
    }
    @ObservationIgnored private var themeScript: String?
    /// The fonts embedded in pages, which they get only while a theme is on.
    @ObservationIgnored private var fonts: ThemeFonts?
    /// Changes reach the open page right away; the user scripts, which carry them to later pages and include the
    /// large fonts script, are reinstalled only when a page loads. So a theme edit doesn't resend them on every tick.
    @ObservationIgnored private var scriptsOutdated = true
    /// The current workspace page, restored per window and tab on relaunch.
    @ObservationIgnored private(set) var pageURL: URL? { didSet { onPageChange?() } }
    /// Called after `pageURL` changes. Set by the window hosting this workspace.
    @ObservationIgnored var onPageChange: (() -> Void)?
    /// Opens a Notion page in a new tab. Set by the window hosting this workspace.
    @ObservationIgnored var onOpenTab: ((URL) -> Void)?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var popups: [WKWebView] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        // Identity providers (Google in particular) refuse sign-in from user agents that don't look like Safari.
        configuration.applicationNameForUserAgent = Self.safariApplicationName
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        configuration.userContentController.add(WeakMessageHandler(self), name: ThemeInjection.chromeMessage)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
        func watch<Value>(_ keyPath: KeyPath<WKWebView, Value>) -> NSKeyValueObservation {
            webView.observe(keyPath) { [weak self] _, _ in Task { @MainActor in self?.updateState() } }
        }
        observations = [watch(\.isLoading), watch(\.estimatedProgress), watch(\.canGoBack), watch(\.canGoForward), watch(\.title), watch(\.url)]
    }

    private static var safariApplicationName: String {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        return "Version/\(major >= 26 ? major : major + 3).0 Safari/605.1.15"
    }

    /// Restyles Notion with a theme, or restores Notion's own look when it's nil.
    func apply(_ theme: PotionTheme?) {
        let script = ThemeInjection.script(for: theme)
        guard script != themeScript else { return }
        themeScript = script
        scriptsOutdated = true
        // Pages load a theme's two font families only while it's on, and get them again only when they change.
        let families = theme?.validated.fonts
        var fontScript = ""
        if families != fonts, let families { fontScript = ThemeInjection.fontScript(for: families) + "\n" }
        fonts = families
        // A tab that hasn't opened a page yet gets all of this from its user scripts.
        guard webView.url != nil else { return }
        run(fontScript + script + ThemeInjection.chromeRefresh)
    }
    private func installScriptsIfOutdated() {
        guard scriptsOutdated else { return }
        scriptsOutdated = false
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        func add(_ source: String) { controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)) }
        add(ThemeInjection.layoutFlag(usesWindowLayout) + ThemeInjection.chromeScript)
        if let fonts { add(ThemeInjection.fontScript(for: fonts)) }
        if let themeScript { add(themeScript) }
    }
    private func run(_ script: String) { webView.evaluateJavaScript(script, completionHandler: nil) }
    /// Shows or hides Notion's own sidebar, as its ⌘\ shortcut does.
    func toggleSidebar() { run(ThemeInjection.toggleSidebarScript) }
    /// Opens Notion's inbox, as its sidebar button does.
    func openInbox() { run(ThemeInjection.pressSidebarButton("Inbox")) }
    /// Starts a new Notion page, as its sidebar button does.
    func newPage() { run(ThemeInjection.pressSidebarButton("New page")) }
    var displayTitle: String { NavigationPolicy.pageTitle(title) }

    /// Loads the offline sample page.
    func showPreview() {
        guard let url = Self.previewURL else { error = "The preview could not be found."; return }
        error = nil
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    func openLogin() { load(Self.loginURL) }
    /// Opens a Notion page, or else the last page, or else the login page (Notion sends signed-in people onward).
    func open(_ url: URL? = nil) {
        let saved = UserDefaults.standard.url(forKey: Self.lastURLKey)
        let requested = url.flatMap { NavigationPolicy.isNotion($0) ? $0 : nil }
        let restorable = saved.flatMap { NavigationPolicy.isRestorable($0) ? $0 : nil }
        load(requested ?? restorable ?? Self.loginURL)
    }
    private func load(_ url: URL) {
        error = nil
        webView.load(URLRequest(url: url))
    }
    func reload() {
        error = nil
        if webView.url == nil { open() } else { webView.reload() }
    }
    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    var canOpenInBrowser: Bool { url.map(NavigationPolicy.canOpenExternally) ?? false }
    func openInBrowser() { if let url = webView.url { NavigationPolicy.openExternally(url) } }
    /// Removes every cookie and cache Potion's web views have stored. All windows share this data store.
    static func removeWebsiteData() async {
        await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        UserDefaults.standard.removeObject(forKey: lastURLKey)
    }
    func returnToLogin() {
        closeAuthPopup()
        isSignedIn = false
        pageURL = nil
        openLogin()
    }
    func closeAuthPopup() {
        guard let popup = authPopup?.webView else { return }
        popup.stopLoading()
        webViewDidClose(popup)
    }

    /// Only changed values are assigned, so a progress tick doesn't redraw everything observing the workspace.
    private func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Workspace, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
    private func updateState() {
        update(\.isLoading, webView.isLoading)
        update(\.progress, webView.estimatedProgress)
        update(\.canGoBack, webView.canGoBack)
        update(\.canGoForward, webView.canGoForward)
        update(\.title, webView.title ?? "")
        update(\.url, webView.url)
        guard let url = webView.url, !url.isFileURL else { return }
        // Notion is a single-page app, so the URL is observed directly rather than waiting for didFinish.
        let signedIn = NavigationPolicy.isWorkspacePage(url)
        if signedIn, NavigationPolicy.isRestorable(url), let safeURL = NavigationPolicy.withoutQuery(url), safeURL != pageURL {
            pageURL = safeURL
            UserDefaults.standard.set(safeURL, forKey: Self.lastURLKey)
        }
        if NavigationPolicy.isNotion(url) { update(\.isSignedIn, signedIn) }
    }

    // MARK: Page chrome

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let url = message.frameInfo.request.url, NavigationPolicy.isNotion(url),
              let body = message.body as? [String: Any], let width = body["sidebarWidth"] as? NSNumber else { return }
        update(\.sidebarWidth, CGFloat(width.doubleValue))
        update(\.inboxCount, (body["inboxCount"] as? NSNumber)?.intValue ?? 0)
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView === self.webView { error = nil }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { handle(error, in: webView) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { handle(error, in: webView) }
    private func handle(_ error: Error, in webView: WKWebView) {
        let nsError = error as NSError
        guard webView === self.webView, nsError.code != NSURLErrorCancelled,
              !(nsError.domain == "WebKitErrorDomain" && nsError.code == 102) else { return }
        self.error = error.localizedDescription
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if webView === self.webView, action.targetFrame?.isMainFrame == true { installScriptsIfOutdated() }
        if action.shouldPerformDownload { decisionHandler(.download); return }
        if action.targetFrame?.isMainFrame == false { decisionHandler(.allow); return }
        if url.isFileURL {
            decisionHandler(url == Self.previewURL ? .allow : .cancel)
            return
        }
        let isPopup = webView !== self.webView
        // ⌘-click opens a Notion page in a new tab, as in Notion's own app.
        if !isPopup, action.navigationType == .linkActivated, action.modifierFlags.contains(.command),
           NavigationPolicy.isNotion(url), let onOpenTab {
            onOpenTab(url)
            decisionHandler(.cancel)
            return
        }
        let decision = isPopup
            ? NavigationPolicy.popupDecision(for: url, from: webView.url)
            : NavigationPolicy.decision(for: url, isLinkClick: action.navigationType == .linkActivated, from: webView.url)
        switch decision {
        case .allow:
            if isPopup, !NavigationPolicy.isBlank(url), authPopup?.webView !== webView {
                authPopup = AuthPopup(webView: webView)
            }
            decisionHandler(.allow)
        case .openExternally:
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            if isPopup { webViewDidClose(webView) }
        case .cancel:
            decisionHandler(.cancel)
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }

    // MARK: Windows

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = action.request.url else { return nil }
        if NavigationPolicy.isNotion(url) && !NavigationPolicy.isSignInPopup(url, hasWindowSize: windowFeatures.width != nil) {
            if let onOpenTab { onOpenTab(url) } else { self.webView.load(action.request) }
            return nil
        }
        guard NavigationPolicy.isTrusted(url) || url.absoluteString.isEmpty else {
            NavigationPolicy.openExternally(url)
            return nil
        }
        // The popup must be a real window: Notion's sign-in page waits for it to report back via window.opener.
        let popup = WKWebView(frame: NSRect(x: 0, y: 0, width: 520, height: 680), configuration: configuration)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popups.append(popup)
        return popup
    }
    func webViewDidClose(_ webView: WKWebView) {
        popups.removeAll { $0 === webView }
        if authPopup?.webView === webView { authPopup = nil }
    }

    // MARK: Downloads and panels

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.begin { response in completionHandler(response == .OK ? panel.url : nil) }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) { self.error = "Download failed: \(error.localizedDescription)" }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.begin { result in completionHandler(result == .OK ? panel.urls : nil) }
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert(); alert.messageText = message; alert.runModal(); completionHandler()
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(okCancelAlert(message).runModal() == .alertFirstButtonReturn)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = okCancelAlert(prompt)
        let field = NSTextField(string: defaultText ?? ""); field.frame = NSRect(x: 0, y: 0, width: 300, height: 24); alert.accessoryView = field
        completionHandler(alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil)
    }
    private func okCancelAlert(_ message: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert
    }
}

/// Script message handlers are retained by WebKit; this breaks the cycle back to the workspace.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

/// Hosts a web view in SwiftUI. The web view is moved into whichever host appears last, so the one
/// persistent Notion web view can move between onboarding and the main window without reloading.
struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        return container
    }
    func updateNSView(_ container: NSView, context: Context) {
        container.layer?.cornerRadius = cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = cornerRadius > 0
        guard webView.superview !== container else { return }
        // Switching tabs swaps which web view this host shows.
        container.subviews.forEach { $0.removeFromSuperview() }
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
    }
}
