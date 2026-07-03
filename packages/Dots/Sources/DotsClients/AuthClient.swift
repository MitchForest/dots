public import Dependencies
public import DotsDomain
import Foundation

/// GitHub sign-in boundary: device flow, user lookup, token refresh, and
/// Keychain persistence. See .docs/plan.md (Phase 1.0).
public struct AuthClient: Sendable {
    public var clearToken: @Sendable () async -> Void
    public var fetchUser: @Sendable (_ token: AuthToken) async throws -> GitHubUser
    public var refreshToken: @Sendable (_ token: AuthToken) async throws -> AuthToken
    public var requestDeviceCode: @Sendable () async throws -> DeviceCodeGrant
    public var storeToken: @Sendable (_ token: AuthToken) async throws -> Void
    public var storedToken: @Sendable () async -> AuthToken?
    public var waitForToken: @Sendable (_ grant: DeviceCodeGrant) async throws -> AuthToken

    public init(
        clearToken: @escaping @Sendable () async -> Void,
        fetchUser: @escaping @Sendable (_ token: AuthToken) async throws -> GitHubUser,
        refreshToken: @escaping @Sendable (_ token: AuthToken) async throws -> AuthToken,
        requestDeviceCode: @escaping @Sendable () async throws -> DeviceCodeGrant,
        storeToken: @escaping @Sendable (_ token: AuthToken) async throws -> Void,
        storedToken: @escaping @Sendable () async -> AuthToken?,
        waitForToken: @escaping @Sendable (_ grant: DeviceCodeGrant) async throws -> AuthToken
    ) {
        self.clearToken = clearToken
        self.fetchUser = fetchUser
        self.refreshToken = refreshToken
        self.requestDeviceCode = requestDeviceCode
        self.storeToken = storeToken
        self.storedToken = storedToken
        self.waitForToken = waitForToken
    }
}

public enum AuthClientError: Error, Equatable {
    case accessDenied
    case codeExpired
    case decodingFailed
    case httpFailure(Int)
    case keychainFailure(Int)
    case oauthFailure(String)
    case unavailable
}

// MARK: - Live

extension AuthClient {
    public static func live(clientID: String) -> Self {
        let keychain = KeychainStore(service: "blog.dots.auth")
        let account = "github-user"
        return Self(
            clearToken: { keychain.delete(account: account) },
            fetchUser: { token in
                var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
                request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let payload: UserPayload = try await Self.send(request)
                return GitHubUser(
                    login: payload.login,
                    name: payload.name,
                    avatarURL: payload.avatarUrl.flatMap(URL.init(string:))
                )
            },
            refreshToken: { token in
                guard let refreshToken = token.refreshToken else {
                    throw AuthClientError.codeExpired
                }
                let payload: TokenPayload = try await Self.send(
                    Self.formRequest(
                        url: "https://github.com/login/oauth/access_token",
                        fields: [
                            "client_id": clientID,
                            "grant_type": "refresh_token",
                            "refresh_token": refreshToken
                        ]
                    )
                )
                return try payload.authToken()
            },
            requestDeviceCode: {
                let payload: DeviceCodePayload = try await Self.send(
                    Self.formRequest(
                        url: "https://github.com/login/device/code",
                        fields: ["client_id": clientID]
                    )
                )
                guard let verificationURL = URL(string: payload.verificationUri) else {
                    throw AuthClientError.decodingFailed
                }
                return DeviceCodeGrant(
                    deviceCode: payload.deviceCode,
                    userCode: payload.userCode,
                    verificationURL: verificationURL,
                    expiresIn: payload.expiresIn,
                    interval: payload.interval
                )
            },
            storeToken: { token in
                let data = try JSONEncoder().encode(StoredToken(token))
                do {
                    try keychain.writeData(data, account: account)
                } catch KeychainStoreError.writeFailed(let status) {
                    throw AuthClientError.keychainFailure(status)
                }
            },
            storedToken: {
                guard let data = keychain.readData(account: account),
                      let stored = try? JSONDecoder().decode(StoredToken.self, from: data)
                else { return nil }
                return AuthToken(accessToken: stored.accessToken, refreshToken: stored.refreshToken)
            },
            waitForToken: { grant in
                var interval = max(1, grant.interval)
                while true {
                    try await Task.sleep(for: .seconds(interval))
                    let payload: TokenPayload = try await Self.send(
                        Self.formRequest(
                            url: "https://github.com/login/oauth/access_token",
                            fields: [
                                "client_id": clientID,
                                "device_code": grant.deviceCode,
                                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
                            ]
                        )
                    )
                    switch payload.error {
                    case "authorization_pending":
                        continue
                    case "slow_down":
                        interval += 5
                    case "expired_token":
                        throw AuthClientError.codeExpired
                    case "access_denied":
                        throw AuthClientError.accessDenied
                    case .some(let other):
                        throw AuthClientError.oauthFailure(other)
                    case .none:
                        return try payload.authToken()
                    }
                }
            }
        )
    }

    private static func formRequest(url: String, fields: [String: String]) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { key, value in
                let escaped = value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
                return "\(key)=\(escaped)"
            }
            .joined(separator: "&")
            .data(using: .utf8)
        return request
    }

    private static func send<Payload: Decodable>(_ request: URLRequest) async throws -> Payload {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AuthClientError.httpFailure(http.statusCode)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let payload = try? decoder.decode(Payload.self, from: data) else {
            throw AuthClientError.decodingFailed
        }
        return payload
    }
}

private struct DeviceCodePayload: Decodable {
    let deviceCode: String
    let expiresIn: Int
    let interval: Int
    let userCode: String
    let verificationUri: String
}

private struct TokenPayload: Decodable {
    let accessToken: String?
    let error: String?
    let refreshToken: String?

    func authToken() throws -> AuthToken {
        guard let accessToken else { throw AuthClientError.decodingFailed }
        return AuthToken(accessToken: accessToken, refreshToken: refreshToken)
    }
}

private struct UserPayload: Decodable {
    let avatarUrl: String?
    let login: String
    let name: String?
}

/// On-Keychain shape of the persisted token (service "blog.dots.auth",
/// account "github-user") — JSON so existing users' tokens keep resolving.
private struct StoredToken: Codable {
    let accessToken: String
    let refreshToken: String?

    init(_ token: AuthToken) {
        self.accessToken = token.accessToken
        self.refreshToken = token.refreshToken
    }
}

// MARK: - Mocks & dependency registration

extension AuthClient {
    // periphery:ignore - test support; SPM test targets sit outside this scan
    /// Signed-in fixture for previews and tests.
    public static func preview(user: GitHubUser = GitHubUser(login: "mitchforest")) -> Self {
        Self(
            clearToken: {},
            fetchUser: { _ in user },
            refreshToken: { $0 },
            requestDeviceCode: {
                DeviceCodeGrant(
                    deviceCode: "device",
                    userCode: "ABCD-1234",
                    verificationURL: URL(string: "https://github.com/login/device")!,
                    expiresIn: 900,
                    interval: 5
                )
            },
            storeToken: { _ in },
            storedToken: { AuthToken(accessToken: "preview") },
            waitForToken: { _ in AuthToken(accessToken: "preview") }
        )
    }

    /// Fails every call — the default test value so unstubbed access is loud.
    public static var unavailable: Self {
        Self(
            clearToken: {},
            fetchUser: { _ in throw AuthClientError.unavailable },
            refreshToken: { _ in throw AuthClientError.unavailable },
            requestDeviceCode: { throw AuthClientError.unavailable },
            storeToken: { _ in throw AuthClientError.unavailable },
            storedToken: { nil },
            waitForToken: { _ in throw AuthClientError.unavailable }
        )
    }
}

enum AuthClientKey: DependencyKey {
    static var liveValue: AuthClient { .live(clientID: GitHubApp.clientID) }
    static var testValue: AuthClient { .unavailable }
}

extension DependencyValues {
    public var authClient: AuthClient {
        get { self[AuthClientKey.self] }
        set { self[AuthClientKey.self] = newValue }
    }
}
