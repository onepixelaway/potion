import SwiftUI
import WebKit
import UniformTypeIdentifiers

@MainActor final class Workspace: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    let webView: WKWebView
    @Published var isPreview = true
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var error: String?
    private var theme = PotionTheme.presets[0]
    private var enabled = true
    private var observations: [NSKeyValueObservation] = []
    private var authWindows: [NSWindow] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
        for key in [\WKWebView.isLoading, \.canGoBack, \.canGoForward] {
            observations.append(webView.observe(key, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.updateState() }
            })
        }
    }

    func apply(_ theme: PotionTheme, enabled: Bool) {
        self.theme = theme
        self.enabled = enabled
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source: ThemeInjection.script(theme: theme, enabled: enabled, includeFonts: true), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.evaluateJavaScript(ThemeInjection.script(theme: theme, enabled: enabled, includeFonts: false), completionHandler: nil)
    }
    func showPreview() {
        guard let url = Bundle.main.url(forResource: "Preview", withExtension: "html") else { error = "The preview could not be found."; return }
        error = nil
        isPreview = true
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    func openNotion() {
        error = nil
        isPreview = false
        let saved = UserDefaults.standard.url(forKey: "potion.lastNotionURL")
        let url = saved.flatMap { NavigationPolicy.isNotion($0) ? $0 : nil } ?? URL(string: "https://app.notion.com/login")!
        webView.load(URLRequest(url: url))
    }
    func reload() { error = nil; webView.reload() }
    func openInBrowser() {
        guard let url = webView.url, NavigationPolicy.canOpenExternally(url) else { return }
        NSWorkspace.shared.open(url)
    }
    private func updateState() {
        isLoading = webView.isLoading
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        isPreview = webView.url?.isFileURL ?? false
        error = nil
        if let url = webView.url, NavigationPolicy.isNotion(url), !url.path.contains("login"), !url.path.contains("signup") {
            // Persist the path only; authentication query parameters are never saved.
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.query = nil
            components?.fragment = nil
            if let safeURL = components?.url { UserDefaults.standard.set(safeURL, forKey: "potion.lastNotionURL") }
        }
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
        if action.shouldPerformDownload { decisionHandler(.download); return }
        if action.targetFrame?.isMainFrame == false { decisionHandler(.allow); return }
        if url.isFileURL {
            let allowed = Bundle.main.url(forResource: "Preview", withExtension: "html")
            decisionHandler(url == allowed ? .allow : .cancel)
        } else if NavigationPolicy.isNotion(url) || NavigationPolicy.isAuthentication(url) || url.absoluteString == "about:blank" {
            decisionHandler(.allow)
        } else {
            if NavigationPolicy.canOpenExternally(url) { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.begin { response in completionHandler(response == .OK ? panel.url : nil) }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) { self.error = "Download failed: \(error.localizedDescription)" }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = action.request.url else { return nil }
        if NavigationPolicy.isNotion(url) { self.webView.load(action.request); return nil }
        guard NavigationPolicy.isAuthentication(url) || url.absoluteString == "about:blank" else {
            if NavigationPolicy.canOpenExternally(url) { NSWorkspace.shared.open(url) }
            return nil
        }
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 720), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Sign in to Notion"
        window.contentView = popup
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        authWindows.append(window)
        return popup
    }
    func webViewDidClose(_ webView: WKWebView) {
        if let window = authWindows.first(where: { $0.contentView === webView }) {
            window.close()
            authWindows.removeAll { $0 === window }
        }
    }
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
        let alert = NSAlert(); alert.messageText = message; alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert(); alert.messageText = prompt; alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: defaultText ?? ""); field.frame = NSRect(x: 0, y: 0, width: 300, height: 24); alert.accessoryView = field
        completionHandler(alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil)
    }
}

struct WebWorkspace: NSViewRepresentable {
    let workspace: Workspace
    func makeNSView(context: Context) -> WKWebView { workspace.webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
