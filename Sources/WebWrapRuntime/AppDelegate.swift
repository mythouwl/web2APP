import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var browserWindow: BrowserWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let url = URL(string: "https://www.google.com")!
        let window = BrowserWindow(url: url, title: "WebWrap")
        window.makeKeyAndOrderFront(nil)
        self.browserWindow = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
