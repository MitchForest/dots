public import Dependencies
public import Foundation

/// Boundary to the web — fetches raw HTML for source capture. Extraction of
/// readable text from that HTML is pure engine work (`ArticleExtractor`).
public struct PageClient: Sendable {
    public var html: @Sendable (_ url: URL) async throws -> String =
        { _ in throw PageClientError.unavailable }

    public init() {}
}

enum PageClientError: Error, Equatable {
    case notHTML
    case unavailable
}

extension PageClient {
    public static func live() -> Self {
        var client = Self()
        client.html = { url in
            var request = URLRequest(url: url)
            // Some publishers gate on user agent; present as a browser.
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
                forHTTPHeaderField: "User-Agent"
            )
            request.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
            else { throw PageClientError.notHTML }
            return html
        }
        return client
    }

    /// Fails every call — the default test value so unstubbed access is loud.
    public static var unavailable: Self { Self() }
}

enum PageClientKey: DependencyKey {
    static var liveValue: PageClient { .live() }
    static var testValue: PageClient { .unavailable }
}

extension DependencyValues {
    public var pageClient: PageClient {
        get { self[PageClientKey.self] }
        set { self[PageClientKey.self] = newValue }
    }
}
