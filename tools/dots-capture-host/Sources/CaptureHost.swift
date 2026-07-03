import DotsClients
import DotsDomain
import DotsEngine
import Foundation

/// Chrome native-messaging host: one framed JSON message in (the page as
/// the writer sees it), one source written into the vault — plus an
/// extraction idea when text was selected — one framed reply out. Headless
/// root over the Clients layer; works whether or not the app is running.
@main
struct CaptureHost {
    struct Payload: Decodable {
        var url: String
        var title: String
        var html: String
        var selection: String?
    }

    struct Reply: Encodable {
        var ok: Bool
        var message: String
    }

    static func main() async {
        guard let payload = readMessage() else {
            write(Reply(ok: false, message: "No message received."))
            return
        }
        do {
            let message = try await capture(payload)
            write(Reply(ok: true, message: message))
        } catch {
            write(Reply(ok: false, message: describe(error)))
        }
    }

    // MARK: Capture

    private static func capture(_ payload: Payload) async throws -> String {
        guard let vault = storedVaultLocation() else {
            throw HostError.noVault
        }
        let client = VaultClient.live()
        let extraction = ArticleExtractor.extract(html: payload.html)
        let url = URL(string: payload.url)
        let title = extraction.title ?? (payload.title.isEmpty ? "Untitled" : payload.title)
        let source = try await client.createSource(
            vault,
            SourceSeed(
                title: title,
                content: extraction.text,
                url: url,
                author: extraction.author,
                site: extraction.site ?? url?.host()
            )
        )

        var message = "Saved “\(title)”"
        let selection = (payload.selection ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !selection.isEmpty {
            _ = try await client.createDot(
                vault,
                DotSeed(
                    content: selection,
                    source: DotSource(kind: .quote, url: url, ref: source.id)
                )
            )
            message += " + extracted your selection"
        }

        // No explicit notification here: VaultClient.createSource posts
        // blog.dots.captured itself, for every capture path.
        return message
    }

    /// The app's stored vault location, read across process boundaries.
    private static func storedVaultLocation() -> URL? {
        guard let path = CFPreferencesCopyAppValue(
            "blog.dots.vault-location" as CFString,
            "blog.dots.macos" as CFString
        ) as? String else { return nil }
        let url = URL(filePath: path, directoryHint: .isDirectory)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path(), isDirectory: &isDirectory),
              isDirectory.boolValue
        else { return nil }
        return url
    }

    private static func describe(_ error: any Error) -> String {
        if let hostError = error as? HostError {
            return hostError.message
        }
        return "Capture failed: \(error.localizedDescription)"
    }

    enum HostError: Error {
        case noVault

        var message: String {
            switch self {
            case .noVault: "Open Dots and set up a vault first."
            }
        }
    }

    // MARK: Chrome native-messaging framing (4-byte LE length + JSON)

    private static func readMessage() -> Payload? {
        let input = FileHandle.standardInput
        guard let lengthData = try? input.read(upToCount: 4), lengthData.count == 4 else {
            return nil
        }
        let length = lengthData.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        let littleEndianLength = Int(UInt32(littleEndian: length))
        guard littleEndianLength > 0, littleEndianLength < 128 * 1024 * 1024,
              let body = try? input.read(upToCount: littleEndianLength),
              body.count == littleEndianLength
        else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: body)
    }

    private static func write(_ reply: Reply) {
        guard let body = try? JSONEncoder().encode(reply) else { return }
        var length = UInt32(body.count).littleEndian
        let header = Data(bytes: &length, count: 4)
        let output = FileHandle.standardOutput
        try? output.write(contentsOf: header)
        try? output.write(contentsOf: body)
    }
}
