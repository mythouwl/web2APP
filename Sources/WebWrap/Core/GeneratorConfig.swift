import Foundation

struct GeneratorConfig: Codable, Equatable {
    var name: String           // "Gmail"
    var url: URL               // "https://mail.google.com"
    var userAgent: String?     // nil = default Safari UA
    var iconData: Data?        // optional pre-rendered .icns bytes; nil = pipeline will fetch/render

    var slug: String {
        let lowered = name.lowercased()
        let allowed = CharacterSet.lowercaseLetters.union(.decimalDigits)
        let scalars = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let collapsed = String(scalars).replacingOccurrences(
            of: #"-+"#, with: "-", options: .regularExpression
        ).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "app" : collapsed
    }

    var bundleId: String { "com.webwrap.\(slug)" }
    var host: String { url.host ?? "" }
}
