import AppKit
@preconcurrency import WebKit

final class WebViewDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    let allowedHost: String

    init(allowedHost: String) {
        self.allowedHost = allowedHost
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }

        // Non-http(s) → hand to system (mailto:, tel:, etc.)
        if let scheme = url.scheme?.lowercased(), scheme != "http", scheme != "https" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel); return
        }

        // Allow same host or subdomain of allowedHost; else open in default browser
        let host = url.host ?? ""
        if hostMatches(host) {
            decisionHandler(.allow)
        } else {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    // Handle target=_blank: load in the same view if same-host, else system browser
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if let host = url.host, hostMatches(host) {
                webView.load(navigationAction.request)
            } else {
                NSWorkspace.shared.open(url)
            }
        }
        return nil
    }

    private func hostMatches(_ host: String) -> Bool {
        host == allowedHost || host.hasSuffix("." + allowedHost)
    }
}
