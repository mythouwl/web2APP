import XCTest
import AppKit
@testable import WebWrap

final class IconRendererTests: XCTestCase {
    func testRenderProducesPNG1024() throws {
        // Synthesize a 100x100 red PNG
        let img = NSImage(size: NSSize(width: 100, height: 100))
        img.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 100, height: 100)).fill()
        img.unlockFocus()
        let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
        let png = rep.representation(using: .png, properties: [:])!

        let out = try IconRenderer.renderMacOSStyle(
            rawIcon: png, originURL: URL(string: "https://example.com")!)
        let outImg = NSImage(data: out)!
        XCTAssertEqual(Int(outImg.size.width), 1024)
        XCTAssertEqual(Int(outImg.size.height), 1024)
    }

    func testMakeICNSProducesValidFile() throws {
        let img = NSImage(size: NSSize(width: 1024, height: 1024))
        img.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
        img.unlockFocus()
        let png = NSBitmapImageRep(data: img.tiffRepresentation!)!
            .representation(using: .png, properties: [:])!

        let icns = try IconRenderer.makeICNS(from: png)
        XCTAssertGreaterThan(icns.count, 1000)
        // Verify "icns" magic header
        let magic = String(data: icns.prefix(4), encoding: .ascii)
        XCTAssertEqual(magic, "icns")
    }

    func testRenderRejectsInvalidInput() {
        XCTAssertThrowsError(
            try IconRenderer.renderMacOSStyle(
                rawIcon: Data([0x00, 0x01, 0x02]),
                originURL: URL(string: "https://example.com")!))
    }
}
