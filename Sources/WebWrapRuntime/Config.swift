import Foundation

struct Config: Codable {
    let url: URL
    let name: String
    let bundleId: String
    let userAgent: String?

    var host: String { url.host ?? "" }

    static func loadFromBundle() throws -> Config {
        guard let path = Bundle.main.url(forResource: "config", withExtension: "json") else {
            throw NSError(domain: "WebWrapRuntime", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "config.json missing from bundle"])
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(Config.self, from: data)
    }
}
