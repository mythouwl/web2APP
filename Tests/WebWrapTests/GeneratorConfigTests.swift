import XCTest
@testable import WebWrap

final class GeneratorConfigTests: XCTestCase {
    func testSlugSimple() {
        let c = GeneratorConfig(name: "Gmail",
                                url: URL(string: "https://mail.google.com")!,
                                userAgent: nil, iconData: nil)
        XCTAssertEqual(c.slug, "gmail")
        XCTAssertEqual(c.bundleId, "com.webwrap.gmail")
    }

    func testSlugStripsSymbolsAndCollapsesDashes() {
        let c = GeneratorConfig(name: "Hello, World! 你好",
                                url: URL(string: "https://x.com")!,
                                userAgent: nil, iconData: nil)
        XCTAssertEqual(c.slug, "hello-world")
    }

    func testSlugAllNonAlphaFallsBack() {
        let c = GeneratorConfig(name: "###",
                                url: URL(string: "https://x.com")!,
                                userAgent: nil, iconData: nil)
        XCTAssertEqual(c.slug, "app")
    }

    func testHostFromURL() {
        let c = GeneratorConfig(name: "Foo",
                                url: URL(string: "https://api.example.com/path")!,
                                userAgent: nil, iconData: nil)
        XCTAssertEqual(c.host, "api.example.com")
    }
}
