import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var browserWindow: BrowserWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config: Config
        do {
            config = try Config.loadFromBundle()
        } catch {
            // Dev fallback when running via `swift run` (no bundled config.json)
            config = Config(
                url: URL(string: "https://www.google.com")!,
                name: "WebWrap Dev",
                bundleId: "com.webwrap.dev",
                userAgent: nil
            )
        }
        let window = BrowserWindow(config: config)
        window.makeKeyAndOrderFront(nil)
        NSApp.mainMenu = MenuBar.build(appName: config.name)
        self.browserWindow = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
