import XCTest
@testable import WebWrap

final class IconFetcherTests: XCTestCase {
    func testParseSizesPicksLargest() {
        XCTAssertEqual(IconFetcher.parseSizes("16x16 32x32 192x192"), 192)
        XCTAssertEqual(IconFetcher.parseSizes("180x180"), 180)
        XCTAssertNil(IconFetcher.parseSizes(""))
        XCTAssertNil(IconFetcher.parseSizes("any"))
    }

    func testPickBestPrefersLargestAbove256() {
        let small = IconCandidate(url: URL(string: "https://x.com")!, declaredSize: 64,
                                  data: Data([0x10]), pixelSize: 64)
        let medium = IconCandidate(url: URL(string: "https://x.com")!, declaredSize: 180,
                                   data: Data([0x20]), pixelSize: 180)
        let large = IconCandidate(url: URL(string: "https://x.com")!, declaredSize: 512,
                                  data: Data([0x30]), pixelSize: 512)
        XCTAssertEqual(IconFetcher.pickBest([small, medium, large]), Data([0x30]))
        XCTAssertEqual(IconFetcher.pickBest([small, medium]), Data([0x20]),
                       "When no candidate is ≥256, pick the overall largest")
        XCTAssertEqual(IconFetcher.pickBest([small]), Data([0x10]))
        XCTAssertNil(IconFetcher.pickBest([]))
    }

    func testGenerateFallbackProducesPNGOfExpectedSize() throws {
        let data = try IconFetcher.generateFallback(siteURL: URL(string: "https://example.com")!)
        let img = NSImage(data: data)
        XCTAssertNotNil(img)
        XCTAssertEqual(Int(img!.size.width), 1024)
        XCTAssertEqual(Int(img!.size.height), 1024)
    }
}
