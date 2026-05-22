import Foundation

enum AppBuilderError: Error {
    case runtimeBinaryNotFound(searched: [String])
}

struct InstalledApp: Identifiable, Hashable {
    var id: String { bundleId }
    let bundleURL: URL
    let bundleId: String
    let name: String
    let url: URL
    let userAgent: String?
}

private struct InstalledAppConfig: Codable {
    let name: String
    let url: URL
    let userAgent: String?
}

struct AppBuilder {
    static var installDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
    }

    /// Locates the WebWrapRuntime binary for the current process. Throws if not found.
    static func locateRuntimeBinary() throws -> URL {
        var searched: [String] = []

        // 1. Env var override
        if let envPath = ProcessInfo.processInfo.environment["WEBWRAP_RUNTIME_PATH"] {
            searched.append(envPath)
            if FileManager.default.isExecutableFile(atPath: envPath) {
                return URL(fileURLWithPath: envPath)
            }
        }

        // 2. Generator app bundle resource
        if let bundled = Bundle.main.url(forResource: "WebWrapRuntime", withExtension: nil) {
            searched.append(bundled.path)
            if FileManager.default.isExecutableFile(atPath: bundled.path) {
                return bundled
            }
        }

        // 3. Walk up from CWD looking for .build/{release,debug}/WebWrapRuntime
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            for config in ["release", "debug"] {
                let candidate = dir
                    .appendingPathComponent(".build")
                    .appendingPathComponent(config)
                    .appendingPathComponent("WebWrapRuntime")
                searched.append(candidate.path)
                if FileManager.default.isExecutableFile(atPath: candidate.path) {
                    return candidate
                }
            }
            let parent = dir.deletingLastPathComponent()
            if parent == dir { break }
            dir = parent
        }

        throw AppBuilderError.runtimeBinaryNotFound(searched: searched)
    }

    /// End-to-end: locate runtime → write bundle in temp → sign → atomic move into ~/Applications.
    @discardableResult
    static func build(config: GeneratorConfig, iconICNS: Data) throws -> URL {
        let runtime = try locateRuntimeBinary()
        let fm = FileManager.default

        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let staged = tmp.appendingPathComponent("\(config.name).app")
        try BundleWriter.write(config: config, iconICNS: iconICNS,
                               runtimeBinary: runtime, at: staged)
        try Codesigner.adhocSign(bundle: staged)

        try fm.createDirectory(at: installDirectory, withIntermediateDirectories: true)
        let final = installDirectory.appendingPathComponent("\(config.name).app")
        if fm.fileExists(atPath: final.path) {
            try fm.removeItem(at: final)
        }
        try fm.moveItem(at: staged, to: final)
        return final
    }

    /// Scans ~/Applications and returns all WebWrap-generated wrappers.
    static func listInstalled() -> [InstalledApp] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: installDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return entries.compactMap { url -> InstalledApp? in
            guard url.pathExtension == "app" else { return nil }
            let plistURL = url.appendingPathComponent("Contents/Info.plist")
            let configURL = url.appendingPathComponent("Contents/Resources/config.json")
            guard
                let plistData = try? Data(contentsOf: plistURL),
                let plist = try? PropertyListSerialization.propertyList(
                    from: plistData, options: [], format: nil) as? [String: Any],
                let bundleId = plist["CFBundleIdentifier"] as? String,
                bundleId.hasPrefix("com.webwrap."),
                let configData = try? Data(contentsOf: configURL),
                let cfg = try? JSONDecoder().decode(InstalledAppConfig.self, from: configData)
            else { return nil }
            return InstalledApp(bundleURL: url, bundleId: bundleId,
                                name: cfg.name, url: cfg.url, userAgent: cfg.userAgent)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func delete(_ app: InstalledApp) throws {
        try FileManager.default.removeItem(at: app.bundleURL)
    }
}
