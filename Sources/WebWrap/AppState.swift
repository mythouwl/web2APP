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
}
