import AppKit
@preconcurrency import WebKit

final class BrowserWindow: NSWindow {
    let webView: WKWebView

    init(url: URL, title: String) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: config)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.title = title
        self.center()
        self.contentView = webView
        webView.load(URLRequest(url: url))
    }
}
