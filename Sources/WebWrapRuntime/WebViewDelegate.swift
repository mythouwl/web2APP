import AppKit
@preconcurrency import WebKit

final class WebViewDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    let allowedHost: String

    init(allowedHost: String) {
        self.allowedHost = allowedHost
    }

    // Schemes WebKit handles internally for in-page content (iframes, srcdoc, blobs,
    // inline data, JS-driven navigations). Must NOT be bounced to NSWorkspace.
    private static let internalWebSchemes: Set<String> = [
        "about", "data", "blob", "javascript", "file",
    ]

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }

        // iframe / sub-frame navigation — never bounce to system, always let WebKit handle.
        // (Pinterest embeds reCAPTCHA, Stripe embeds checkout, etc.)
        if navigationAction.targetFrame?.isMainFrame != true {
            decisionHandler(.allow); return
        }

        let scheme = url.scheme?.lowercased() ?? ""

        // Internal web schemes for the main frame (about:blank, data:, etc.) → allow
        if Self.internalWebSchemes.contains(scheme) {
            decisionHandler(.allow); return
        }

        // External schemes that need a real app (mailto:, tel:, x-apple-* etc.) → system
        if scheme != "http", scheme != "https" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel); return
        }

        // Top-level http(s): same host or subdomain stays in wrapper; else system browser
        let host = url.host ?? ""
        if hostMatches(host) {
            decisionHandler(.allow)
        } else {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    // Handle target=_blank: load in the same view if same-host, else system browser.
    // Skip non-http(s) — those are handled by the main nav policy above.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme != "http", scheme != "https" {
            return nil  // let the main policy decide
        }
        if let host = url.host, hostMatches(host) {
            webView.load(navigationAction.request)
        } else {
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    private func hostMatches(_ host: String) -> Bool {
        host == allowedHost || host.hasSuffix("." + allowedHost)
    }
}
