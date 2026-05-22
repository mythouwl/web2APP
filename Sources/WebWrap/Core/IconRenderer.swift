import Foundation
import AppKit

enum IconRendererError: Error {
    case decodeFailed
    case renderFailed
    case iconutilFailed(String)
    case sipsFailed(size: Int, message: String)
}

struct IconRenderer {
    /// Takes raw icon data (any format NSImage can decode), returns a styled 1024×1024 PNG.
    /// Applies a macOS-style squircle clip, white background for transparent inputs,
    /// and centers the source within 824×824 (100px padding).
    static func renderMacOSStyle(rawIcon: Data, originURL: URL) throws -> Data {
        guard let src = NSImage(data: rawIcon) else { throw IconRendererError.decodeFailed }
        guard src.size.width > 0, src.size.height > 0 else { throw IconRendererError.renderFailed }

        // Render into an offscreen bitmap rep so we don't depend on lockFocus/tiffRepresentation
        // (which can fail under sandboxed/headless test contexts).
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1024, pixelsHigh: 1024,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 32
        ) else { throw IconRendererError.renderFailed }

        guard let cgCtx = NSGraphicsContext(bitmapImageRep: rep) else {
            throw IconRendererError.renderFailed
        }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = cgCtx
        cgCtx.imageInterpolation = .high

        // Squircle clip — approximate Apple's continuous-curve corner with ~22% radius.
        // Real continuous curves require Core Animation or custom path math; this rounded-
        // rect is visually close enough for our purposes.
        let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024),
                                xRadius: 230, yRadius: 230)
        path.addClip()

        // Background — if the source has transparent corners, fill white so squircle is visible.
        if hasTransparentEdges(src) {
            NSColor.white.setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
        }

        // Draw source aspect-fit into 824×824, centered.
        let inner = NSRect(x: 100, y: 100, width: 824, height: 824)
        let srcSize = src.size
        let scale = min(inner.width / srcSize.width, inner.height / srcSize.height)
        let drawSize = NSSize(width: srcSize.width * scale, height: srcSize.height * scale)
        let drawRect = NSRect(
            x: inner.midX - drawSize.width / 2,
            y: inner.midY - drawSize.height / 2,
            width: drawSize.width, height: drawSize.height
        )
        src.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        cgCtx.flushGraphics()

        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw IconRendererError.renderFailed
        }
        return png
    }

    static func hasTransparentEdges(_ img: NSImage) -> Bool {
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return true }
        let corners = [(0, 0), (rep.pixelsWide - 1, 0),
                       (0, rep.pixelsHigh - 1), (rep.pixelsWide - 1, rep.pixelsHigh - 1)]
        for (x, y) in corners {
            if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) < 0.5 {
                return true
            }
        }
        return false
    }

    /// Converts a 1024x1024 PNG into a .icns blob via sips + iconutil.
    static func makeICNS(from png1024: Data) throws -> Data {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let iconset = tmp.appendingPathComponent("AppIcon.iconset")
        try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
        let srcPNG = tmp.appendingPathComponent("src.png")
        try png1024.write(to: srcPNG)

        let sizes: [(Int, String)] = [
            (16,   "icon_16x16.png"),
            (32,   "icon_16x16@2x.png"),
            (32,   "icon_32x32.png"),
            (64,   "icon_32x32@2x.png"),
            (128,  "icon_128x128.png"),
            (256,  "icon_128x128@2x.png"),
            (256,  "icon_256x256.png"),
            (512,  "icon_256x256@2x.png"),
            (512,  "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]
        for (px, name) in sizes {
            try runSips(input: srcPNG, output: iconset.appendingPathComponent(name), size: px)
        }

        let outICNS = tmp.appendingPathComponent("AppIcon.icns")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        proc.arguments = ["-c", "icns", iconset.path, "-o", outICNS.path]
        let err = Pipe(); proc.standardError = err
        try proc.run(); proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw IconRendererError.iconutilFailed(msg)
        }
        return try Data(contentsOf: outICNS)
    }

    static func runSips(input: URL, output: URL, size: Int) throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        proc.arguments = ["-z", "\(size)", "\(size)", input.path, "--out", output.path]
        let outPipe = Pipe(); let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        try proc.run(); proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let msg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                             encoding: .utf8) ?? ""
            throw IconRendererError.sipsFailed(size: size, message: msg)
        }
    }
}
