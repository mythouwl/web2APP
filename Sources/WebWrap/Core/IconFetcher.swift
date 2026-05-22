import Foundation
import AppKit
import SwiftSoup

struct IconCandidate: Equatable {
    let url: URL
    let declaredSize: Int?    // from sizes="180x180"; nil if unknown
    let data: Data
    let pixelSize: Int        // measured after decode
}

enum IconFetcherError: Error {
    case noCandidates
}

struct IconFetcher {
    /// End-to-end: collect candidates, pick best (or fall back), render macOS-style 1024 PNG.
    static func fetch(siteURL: URL) async throws -> Data {
        let candidates = await collectCandidates(siteURL: siteURL)
        let best: Data
        if let picked = pickBest(candidates) {
            best = picked
        } else {
            best = try generateFallback(siteURL: siteURL)
        }
        return try IconRenderer.renderMacOSStyle(rawIcon: best, originURL: siteURL)
    }

    /// Collects all available icon candidates from the site in parallel.
    static func collectCandidates(siteURL: URL) async -> [IconCandidate] {
        async let htmlAndManifest = parseHTMLForIcons(siteURL: siteURL)
        async let appleTouch = fetchIfExists(siteURL.appendingPathComponent("apple-touch-icon.png"))
        async let appleTouchPrecomposed = fetchIfExists(
            siteURL.appendingPathComponent("apple-touch-icon-precomposed.png"))
        async let favicon = fetchIfExists(siteURL.appendingPathComponent("favicon.ico"))

        var results = await htmlAndManifest
        for opt in [await appleTouch, await appleTouchPrecomposed, await favicon] {
            if let c = opt { results.append(c) }
        }
        return results
    }

    /// Picks the largest candidate, preferring those ≥ 256px. Returns the raw data of the chosen icon.
    static func pickBest(_ candidates: [IconCandidate]) -> Data? {
        guard !candidates.isEmpty else { return nil }
        let large = candidates.filter { $0.pixelSize >= 256 }
        let pool = large.isEmpty ? candidates : large
        return pool.max(by: { $0.pixelSize < $1.pixelSize })?.data
    }

    /// Parses HTML for <link rel=icon|apple-touch-icon|shortcut icon> and manifest icons.
    static func parseHTMLForIcons(siteURL: URL) async -> [IconCandidate] {
        guard let (data, _) = try? await URLSession.shared.data(from: siteURL),
              let html = String(data: data, encoding: .utf8),
              let doc = try? SwiftSoup.parse(html, siteURL.absoluteString)
        else { return [] }

        var candidateURLs: [(URL, Int?)] = []
        if let links = try? doc.select("link[rel~=(?i)(apple-touch-icon|icon|shortcut icon)]") {
            for l in links {
                guard let href = try? l.attr("href"), !href.isEmpty,
                      let abs = URL(string: href, relativeTo: siteURL)?.absoluteURL
                else { continue }
                let sizesAttr = (try? l.attr("sizes")) ?? ""
                candidateURLs.append((abs, parseSizes(sizesAttr)))
            }
        }
        if let manifestHref = try? doc.select("link[rel=manifest]").first()?.attr("href"),
           !manifestHref.isEmpty,
           let manifestURL = URL(string: manifestHref, relativeTo: siteURL) {
            let mcs = await parseManifest(manifestURL: manifestURL, base: siteURL)
            candidateURLs.append(contentsOf: mcs)
        }

        var out: [IconCandidate] = []
        for (u, declared) in candidateURLs {
            if let c = await fetchIfExists(u, declared: declared) {
                out.append(c)
            }
        }
        return out
    }

    static func parseManifest(manifestURL: URL, base: URL) async -> [(URL, Int?)] {
        guard let (data, _) = try? await URLSession.shared.data(from: manifestURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let icons = obj["icons"] as? [[String: Any]]
        else { return [] }
        return icons.compactMap { dict -> (URL, Int?)? in
            guard let src = dict["src"] as? String,
                  let abs = URL(string: src, relativeTo: base) else { return nil }
            let sizes = (dict["sizes"] as? String) ?? ""
            return (abs.absoluteURL, parseSizes(sizes))
        }
    }

    /// Parses a `sizes` attribute like "32x32 64x64" and returns the largest dimension.
    static func parseSizes(_ attr: String) -> Int? {
        let pieces = attr.lowercased().split(separator: " ")
        let sizes = pieces.compactMap { p -> Int? in
            let parts = p.split(separator: "x")
            guard parts.count == 2, let n = Int(parts[0]) else { return nil }
            return n
        }
        return sizes.max()
    }

    static func fetchIfExists(_ url: URL, declared: Int? = nil) async -> IconCandidate? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              !data.isEmpty
        else { return nil }
        guard let pixelSize = decodedPixelSize(of: data) else { return nil }
        return IconCandidate(url: url, declaredSize: declared, data: data, pixelSize: pixelSize)
    }

    static func decodedPixelSize(of data: Data) -> Int? {
        guard let image = NSImage(data: data) else { return nil }
        let maxRep = image.representations.map { max($0.pixelsWide, $0.pixelsHigh) }.max() ?? 0
        if maxRep > 0 { return maxRep }
        return Int(max(image.size.width, image.size.height))
    }

    /// Fallback: render a 1024x1024 PNG with the first letter of the host on a colored square.
    static func generateFallback(siteURL: URL) throws -> Data {
        let letter = String(siteURL.host?.first ?? "?").uppercased()
        let size = NSSize(width: 1024, height: 1024)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 600, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: letter, attributes: attrs)
        let strSize = str.size()
        str.draw(at: NSPoint(x: (size.width - strSize.width) / 2,
                             y: (size.height - strSize.height) / 2))
        img.unlockFocus()
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { throw IconFetcherError.noCandidates }
        return png
    }
}
