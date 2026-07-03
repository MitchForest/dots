/// GitHub user access token pair. Access tokens expire (~8h); the refresh
/// token mints a replacement without re-running the device flow.
public struct AuthToken: Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String?

    public init(accessToken: String, refreshToken: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}
