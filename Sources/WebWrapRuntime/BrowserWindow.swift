import AppKit
@preconcurrency import WebKit

final class BrowserWindow: NSWindow, NSToolbarDelegate {
    let webView: WKWebView
    private var navDelegate: WebViewDelegate?
    private var titleObservation: NSKeyValueObservation?

    init(config: Config) {
        let webConfig = WKWebViewConfiguration()
        webConfig.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: webConfig)
        if let ua = config.userAgent { webView.customUserAgent = ua }

        let delegate = WebViewDelegate(allowedHost: config.host)
        webView.navigationDelegate = delegate
        webView.uiDelegate = delegate
        self.navDelegate = delegate  // retain — WKWebView holds delegates weakly

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.title = config.name
        self.center()
        self.contentView = webView

        let toolbar = NSToolbar(identifier: "main")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        self.toolbar = toolbar

        webView.load(URLRequest(url: config.url))

        titleObservation = webView.observe(\.title, options: [.new]) { _, change in
            let title = (change.newValue ?? nil) ?? ""
            DispatchQueue.main.async {
                NSApp.dockTile.badgeLabel = BrowserWindow.extractBadge(from: title)
            }
        }
    }

    static func extractBadge(from title: String) -> String? {
        // Match leading "(N) ..." or "[N] ..." patterns common in Gmail/Slack/etc.
        let pattern = #"^[\(\[](\d+)[\)\]]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let range = Range(match.range(at: 1), in: title) else {
            return nil
        }
        return String(title[range])
    }

    // MARK: - Toolbar items

    private enum ItemID {
        static let back = NSToolbarItem.Identifier("back")
        static let forward = NSToolbarItem.Identifier("forward")
        static let reload = NSToolbarItem.Identifier("reload")
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ItemID.back, ItemID.forward, .flexibleSpace, ItemID.reload]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ItemID.back, ItemID.forward, ItemID.reload, .flexibleSpace, .space]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch id {
        case ItemID.back:    return makeItem(id, symbol: "chevron.left",    action: #selector(goBackAction(_:)))
        case ItemID.forward: return makeItem(id, symbol: "chevron.right",   action: #selector(goForwardAction(_:)))
        case ItemID.reload:  return makeItem(id, symbol: "arrow.clockwise", action: #selector(reloadAction(_:)))
        default: return nil
        }
    }

    private func makeItem(_ id: NSToolbarItem.Identifier,
                          symbol: String,
                          action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: id)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.target = self
        item.action = action
        return item
    }

    @objc func goBackAction(_ sender: Any?)    { webView.goBack() }
    @objc func goForwardAction(_ sender: Any?) { webView.goForward() }
    @objc func reloadAction(_ sender: Any?)    { webView.reload() }
}
