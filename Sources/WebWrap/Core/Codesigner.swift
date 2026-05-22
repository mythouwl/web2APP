import Foundation

enum CodesignerError: Error {
    case signingFailed(stderr: String, code: Int32)
}

struct Codesigner {
    /// Ad-hoc signs the given bundle via /usr/bin/codesign --force --deep --sign -.
    static func adhocSign(bundle: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--deep", "--sign", "-", bundle.path]

        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw CodesignerError.signingFailed(stderr: msg, code: process.terminationStatus)
        }
    }
}
