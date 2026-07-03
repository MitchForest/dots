public import Foundation

public struct GitHubUser: Equatable, Sendable {
    // periphery:ignore - GitHub payload surface; profile UI reads it in a later pass
    public var avatarURL: URL?
    public var login: String
    // periphery:ignore - GitHub payload surface; profile UI reads it in a later pass
    public var name: String?

    public init(login: String, name: String? = nil, avatarURL: URL? = nil) {
        self.avatarURL = avatarURL
        self.login = login
        self.name = name
    }
}
