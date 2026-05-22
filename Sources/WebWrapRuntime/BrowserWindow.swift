import AppKit
@preconcurrency import WebKit

final class BrowserWindow: NSWindow, NSToolbarDelegate {
    let webView: WKWebView
    private var navDelegate: WebViewDelegate?
    private var titleObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?
    private let addressBar = AddressBar(frame: NSRect(x: 0, y: 0, width: 400, height: 28))

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
        self.toolbarStyle = .unifiedCompact  // ~28pt instead of ~38pt
        self.titleVisibility = .hidden

        addressBar.pageTitle = config.name
        addressBar.pageURL = config.url.absoluteString

        webView.load(URLRequest(url: config.url))

        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, change in
            let title = (change.newValue ?? nil) ?? ""
            DispatchQueue.main.async {
                NSApp.dockTile.badgeLabel = BrowserWindow.extractBadge(from: title)
                if !title.isEmpty { self?.addressBar.pageTitle = title }
            }
        }
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, change in
            let url = (change.newValue ?? nil)?.absoluteString ?? ""
            DispatchQueue.main.async {
                if !url.isEmpty { self?.addressBar.pageURL = url }
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
        static let navGroup     = NSToolbarItem.Identifier("navGroup")
        static let addressBar   = NSToolbarItem.Identifier("addressBar")
        static let openExternal = NSToolbarItem.Identifier("openExternal")
        static let reload       = NSToolbarItem.Identifier("reload")
        static let divider      = NSToolbarItem.Identifier("divider")
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ItemID.navGroup, .flexibleSpace, ItemID.addressBar, .flexibleSpace, ItemID.reload, .space, ItemID.divider, .space, ItemID.openExternal]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ItemID.navGroup, ItemID.addressBar, ItemID.openExternal, ItemID.reload, ItemID.divider, .flexibleSpace, .space]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch id {
        case ItemID.navGroup:
            let group = NSToolbarItemGroup(
                itemIdentifier: id,
                images: [
                    NSImage(systemSymbolName: "chevron.left",  accessibilityDescription: "Back")!,
                    NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")!,
                ],
                selectionMode: .momentary,
                labels: ["Back", "Forward"],
                target: self,
                action: #selector(navGroupAction(_:))
            )
            group.controlRepresentation = .expanded
            group.label = "Navigation"
            return group
        case ItemID.addressBar:
            let item = NSToolbarItem(itemIdentifier: id)
            item.view = addressBar
            item.minSize = NSSize(width: 240, height: 24)
            item.maxSize = NSSize(width: 9999, height: 24)
            item.label = ""
            return item
        case ItemID.openExternal:
            return makeItem(id, symbol: "safari",          action: #selector(openExternalAction(_:)), label: "Open in Browser")
        case ItemID.reload:
            return makeItem(id, symbol: "arrow.clockwise", action: #selector(reloadAction(_:)),       label: "Reload")
        case ItemID.divider:
            let item = NSToolbarItem(itemIdentifier: id)
            let line = NSBox()
            line.boxType = .separator
            line.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                line.widthAnchor.constraint(equalToConstant: 1),
                line.heightAnchor.constraint(equalToConstant: 22),
            ])
            item.view = line
            item.label = ""
            return item
        default:
            return nil
        }
    }

    @objc func navGroupAction(_ sender: NSToolbarItemGroup) {
        if sender.selectedIndex == 0 {
            webView.goBack()
        } else {
            webView.goForward()
        }
    }

    private func makeItem(_ id: NSToolbarItem.Identifier,
                          symbol: String,
                          action: Selector,
                          label: String) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: id)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.label = label
        item.toolTip = label
        item.target = self
        item.action = action
        return item
    }

    @objc func goBackAction(_ sender: Any?)    { webView.goBack() }
    @objc func goForwardAction(_ sender: Any?) { webView.goForward() }
    @objc func reloadAction(_ sender: Any?)    { webView.reload() }
    @objc func openExternalAction(_ sender: Any?) {
        if let url = webView.url {
            NSWorkspace.shared.open(url)
        }
    }
}
