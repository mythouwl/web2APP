import XCTest
@testable import WebWrap

final class AppBuilderTests: XCTestCase {
    func testLocateRuntimeBinaryFindsIt() throws {
        let url = try AppBuilder.locateRuntimeBinary()
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: url.path))
    }

    func testBuildEndToEnd() throws {
        // Guard: skip if runtime not present (e.g., partial build environment)
        guard (try? AppBuilder.locateRuntimeBinary()) != nil else {
            throw XCTSkip("Runtime binary not present; run `swift build` first")
        }

        let name = "WW Test \(UUID().uuidString.prefix(8))"
        let config = GeneratorConfig(
            name: name,
            url: URL(string: "https://example.com")!,
            userAgent: nil, iconData: nil)
        let icon = Data([1, 2, 3])

        let url = try AppBuilder.build(config: config, iconICNS: icon)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.lastPathComponent, "\(name).app")

        let installed = AppBuilder.listInstalled()
        XCTAssertTrue(installed.contains { $0.bundleId == config.bundleId },
                      "Newly built app should appear in listInstalled()")

        // Idempotent re-build replaces existing
        let url2 = try AppBuilder.build(config: config, iconICNS: icon)
        XCTAssertEqual(url.standardizedFileURL.path, url2.standardizedFileURL.path)

        // Delete via API
        if let appModel = installed.first(where: { $0.bundleId == config.bundleId }) {
            try AppBuilder.delete(appModel)
            XCTAssertFalse(FileManager.default.fileExists(atPath: appModel.bundleURL.path))
        }
    }
}
