import AppKit
@preconcurrency import WebKit

final class BrowserWindow: NSWindow {
    let webView: WKWebView

    init(config: Config) {
        let webConfig = WKWebViewConfiguration()
        webConfig.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: webConfig)
        if let ua = config.userAgent { webView.customUserAgent = ua }

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.title = config.name
        self.center()
        self.contentView = webView
        webView.load(URLRequest(url: config.url))
    }
}
