import XCTest
@testable import WebWrap

final class BundleWriterTests: XCTestCase {
    func testWritesBundleStructure() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tmp) }
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)

        // Fake runtime: a small executable file
        let fakeRuntime = tmp.appendingPathComponent("FakeRuntime")
        try "#!/bin/sh\necho hi\n".write(to: fakeRuntime, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeRuntime.path)

        let config = GeneratorConfig(
            name: "Example",
            url: URL(string: "https://example.com")!,
            userAgent: "MyUA/1.0",
            iconData: nil)
        let icon = Data([0x69, 0x63, 0x6e, 0x73]) // "icns" magic-ish
        let dest = tmp.appendingPathComponent("Example.app")

        try BundleWriter.write(config: config, iconICNS: icon,
                               runtimeBinary: fakeRuntime, at: dest)

        XCTAssertTrue(fm.fileExists(atPath: dest.appendingPathComponent("Contents/MacOS/WebWrapRuntime").path))
        XCTAssertTrue(fm.fileExists(atPath: dest.appendingPathComponent("Contents/Info.plist").path))
        XCTAssertTrue(fm.fileExists(atPath: dest.appendingPathComponent("Contents/Resources/AppIcon.icns").path))

        // Verify config.json content
        let configURL = dest.appendingPathComponent("Contents/Resources/config.json")
        let configData = try Data(contentsOf: configURL)
        let decoded = try JSONSerialization.jsonObject(with: configData) as! [String: Any]
        XCTAssertEqual(decoded["url"] as? String, "https://example.com")
        XCTAssertEqual(decoded["name"] as? String, "Example")
        XCTAssertEqual(decoded["bundleId"] as? String, "com.webwrap.example")
        XCTAssertEqual(decoded["userAgent"] as? String, "MyUA/1.0")

        // Verify Info.plist content
        let plistURL = dest.appendingPathComponent("Contents/Info.plist")
        let plistData = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(
            from: plistData, options: [], format: nil) as! [String: Any]
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "com.webwrap.example")
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "WebWrapRuntime")
        XCTAssertEqual(plist["CFBundleName"] as? String, "Example")

        // Verify runtime was actually copied (and executable)
        let copiedRuntime = dest.appendingPathComponent("Contents/MacOS/WebWrapRuntime")
        let attrs = try fm.attributesOfItem(atPath: copiedRuntime.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.int16Value ?? 0
        XCTAssertEqual(perms & 0o111, 0o111, "runtime should have all execute bits set")
    }

    func testOmitsUserAgentWhenNil() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tmp) }
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        let fakeRuntime = tmp.appendingPathComponent("FakeRuntime")
        try "#!/bin/sh\n".write(to: fakeRuntime, atomically: true, encoding: .utf8)

        let config = GeneratorConfig(name: "NoUA",
                                     url: URL(string: "https://no.example")!,
                                     userAgent: nil, iconData: nil)
        let dest = tmp.appendingPathComponent("NoUA.app")
        try BundleWriter.write(config: config, iconICNS: Data([1]),
                               runtimeBinary: fakeRuntime, at: dest)

        let configData = try Data(contentsOf: dest.appendingPathComponent("Contents/Resources/config.json"))
        let decoded = try JSONSerialization.jsonObject(with: configData) as! [String: Any]
        XCTAssertNil(decoded["userAgent"])
    }

    func testReplacesExistingBundle() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tmp) }
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        let fakeRuntime = tmp.appendingPathComponent("FakeRuntime")
        try "#!/bin/sh\n".write(to: fakeRuntime, atomically: true, encoding: .utf8)

        let config = GeneratorConfig(name: "Foo",
                                     url: URL(string: "https://foo")!,
                                     userAgent: nil, iconData: nil)
        let dest = tmp.appendingPathComponent("Foo.app")
        try BundleWriter.write(config: config, iconICNS: Data([1]),
                               runtimeBinary: fakeRuntime, at: dest)
        // Write again — must not throw
        try BundleWriter.write(config: config, iconICNS: Data([2]),
                               runtimeBinary: fakeRuntime, at: dest)
        XCTAssertTrue(fm.fileExists(atPath: dest.appendingPathComponent("Contents/Info.plist").path))
    }
}
