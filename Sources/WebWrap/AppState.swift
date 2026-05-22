import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var wrappers: [InstalledApp] = []
    @Published var selection: InstalledApp.ID?
    @Published var lastError: String?

    func refresh() {
        wrappers = AppBuilder.listInstalled()
        if let sel = selection, !wrappers.contains(where: { $0.id == sel }) {
            selection = wrappers.first?.id
        }
    }

    func createAuto(name: String, url: URL, userAgent: String?) async {
        let config = GeneratorConfig(name: name, url: url, userAgent: userAgent, iconData: nil)
        do {
            _ = try await AppBuilder.buildAutoIcon(config: config)
            refresh()
            selection = config.bundleId
        } catch {
            lastError = "Create failed: \(error)"
        }
    }

    func createWithImage(name: String, url: URL, userAgent: String?, imageData: Data) {
        let config = GeneratorConfig(name: name, url: url, userAgent: userAgent, iconData: nil)
        do {
            _ = try AppBuilder.buildWithCustomImage(config: config, imageData: imageData)
            refresh()
            selection = config.bundleId
        } catch {
            lastError = "Create failed: \(error)"
        }
    }

    func delete(_ app: InstalledApp) {
        do {
            try AppBuilder.delete(app)
            refresh()
        } catch {
            lastError = "Delete failed: \(error)"
        }
    }

    func reveal(_ app: InstalledApp) {
        NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
    }

    func launch(_ app: InstalledApp) {
        NSWorkspace.shared.open(app.bundleURL)
    }

    func regenerate(_ app: InstalledApp, newName: String, newURL: URL, newUA: String?) async {
        // Delete then re-create; bundleId stays stable if slug derives identically.
        delete(app)
        await createAuto(name: newName, url: newURL, userAgent: newUA)
    }

    /// Replaces the WebWrapRuntime binary inside every installed wrapper with the current
    /// runtime, then re-signs each. Returns the number successfully updated.
    func updateAllWrappers() async -> Int {
        let appsSnapshot = wrappers
        guard let runtime = try? AppBuilder.locateRuntimeBinary() else { return 0 }
        let runtimePath = runtime.path
        let result = await Task.detached(priority: .userInitiated) { () -> Int in
            var count = 0
            let fm = FileManager.default
            for app in appsSnapshot {
                let dst = app.bundleURL.appendingPathComponent("Contents/MacOS/WebWrapRuntime")
                do {
                    if fm.fileExists(atPath: dst.path) {
                        try fm.removeItem(at: dst)
                    }
                    try fm.copyItem(at: URL(fileURLWithPath: runtimePath), to: dst)
                    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst.path)
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
                    proc.arguments = ["--force", "--deep", "--sign", "-", app.bundleURL.path]
                    proc.standardOutput = Pipe()
                    proc.standardError = Pipe()
                    try proc.run()
                    proc.waitUntilExit()
                    if proc.terminationStatus == 0 { count += 1 }
                } catch {
                    // skip this wrapper, continue
                }
            }
            return count
        }.value
        refresh()
        return result
    }
}
