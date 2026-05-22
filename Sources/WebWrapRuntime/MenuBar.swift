import AppKit

enum MenuBar {
    static func build(appName: String) -> NSMenu {
        let main = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About \(appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide \(appName)",
            action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu

        // Edit menu — provides standard text-field shortcuts to web content
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        for (title, sel, key) in [
            ("Undo",        "undo:",        "z"),
            ("Redo",        "redo:",        "Z"),
            ("Cut",         "cut:",         "x"),
            ("Copy",        "copy:",        "c"),
            ("Paste",       "paste:",       "v"),
            ("Select All",  "selectAll:",   "a"),
        ] {
            editMenu.addItem(NSMenuItem(title: title, action: Selector(sel), keyEquivalent: key))
        }
        editItem.submenu = editMenu

        // View menu — back / forward / reload routed via responder chain
        let viewItem = NSMenuItem()
        main.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(NSMenuItem(title: "Back",
            action: #selector(BrowserWindow.goBackAction(_:)), keyEquivalent: "["))
        viewMenu.addItem(NSMenuItem(title: "Forward",
            action: #selector(BrowserWindow.goForwardAction(_:)), keyEquivalent: "]"))
        viewMenu.addItem(NSMenuItem(title: "Reload",
            action: #selector(BrowserWindow.reloadAction(_:)), keyEquivalent: "r"))
        viewMenu.addItem(.separator())
        let openExt = NSMenuItem(title: "Open in Default Browser",
            action: #selector(BrowserWindow.openExternalAction(_:)), keyEquivalent: "o")
        openExt.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(openExt)
        viewItem.submenu = viewMenu

        // Window menu
        let winItem = NSMenuItem()
        main.addItem(winItem)
        let winMenu = NSMenu(title: "Window")
        winMenu.addItem(NSMenuItem(title: "Close",
            action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        winMenu.addItem(NSMenuItem(title: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        winItem.submenu = winMenu

        return main
    }
}
