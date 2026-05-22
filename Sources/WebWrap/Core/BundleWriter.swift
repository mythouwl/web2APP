import Foundation

enum BundleWriterError: Error {
    case writeFailed(String)
}

struct BundleWriter {
    /// Builds an unsigned .app at `destination`. Caller signs and moves to ~/Applications.
    static func write(config: GeneratorConfig,
                      iconICNS: Data,
                      runtimeBinary: URL,
                      at destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        let contents = destination.appendingPathComponent("Contents")
        let macOS = contents.appendingPathComponent("MacOS")
        let resources = contents.appendingPathComponent("Resources")
        try fm.createDirectory(at: macOS, withIntermediateDirectories: true)
        try fm.createDirectory(at: resources, withIntermediateDirectories: true)

        // Copy runtime, ensure executable bit
        let runtimeDst = macOS.appendingPathComponent("WebWrapRuntime")
        try fm.copyItem(at: runtimeBinary, to: runtimeDst)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeDst.path)

        // Info.plist
        let plist: [String: Any] = [
            "CFBundleExecutable": "WebWrapRuntime",
            "CFBundleIdentifier": config.bundleId,
            "CFBundleName": config.name,
            "CFBundleDisplayName": config.name,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "13.0",
            "NSHighResolutionCapable": true,
            "CFBundleIconFile": "AppIcon",
        ]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: contents.appendingPathComponent("Info.plist"))

        // Icon
        try iconICNS.write(to: resources.appendingPathComponent("AppIcon.icns"))

        // config.json — shape must match Sources/WebWrapRuntime/Config.swift
        // (fields: url, name, bundleId, userAgent?)
        var runtimeConfig: [String: Any] = [
            "url": config.url.absoluteString,
            "name": config.name,
            "bundleId": config.bundleId,
        ]
        if let ua = config.userAgent {
            runtimeConfig["userAgent"] = ua
        }
        let configData = try JSONSerialization.data(
            withJSONObject: runtimeConfig, options: [.prettyPrinted, .sortedKeys])
        try configData.write(to: resources.appendingPathComponent("config.json"))
    }
}
