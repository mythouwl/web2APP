import XCTest
@testable import WebWrap

final class CodesignerTests: XCTestCase {
    func testAdhocSignsAGeneratedBundle() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tmp) }
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)

        // Use a real Mach-O so codesign accepts it
        let fakeRuntime = tmp.appendingPathComponent("FakeRuntime")
        try fm.copyItem(at: URL(fileURLWithPath: "/bin/echo"), to: fakeRuntime)

        let config = GeneratorConfig(
            name: "SignTest", url: URL(string: "https://example.com")!,
            userAgent: nil, iconData: nil)
        let dest = tmp.appendingPathComponent("SignTest.app")
        try BundleWriter.write(config: config, iconICNS: Data([1,2,3]),
                               runtimeBinary: fakeRuntime, at: dest)

        try Codesigner.adhocSign(bundle: dest)

        // Verify via `codesign -dv` (writes to stderr; exit code 0 = valid signature)
        let verify = Process()
        verify.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        verify.arguments = ["-dv", dest.path]
        let err = Pipe(); verify.standardError = err
        verify.standardOutput = Pipe()
        try verify.run(); verify.waitUntilExit()
        XCTAssertEqual(verify.terminationStatus, 0,
                       "codesign -dv failed: \(String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")")
    }
}
