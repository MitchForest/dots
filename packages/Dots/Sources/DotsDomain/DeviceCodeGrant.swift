public import Foundation

/// GitHub device-flow grant: show `userCode`, send the user to
/// `verificationURL`, and poll with `deviceCode` every `interval` seconds.
public struct DeviceCodeGrant: Equatable, Sendable {
    public var deviceCode: String
    // periphery:ignore - device-flow payload; polling honors expiry in a later pass
    public var expiresIn: Int
    public var interval: Int
    public var userCode: String
    public var verificationURL: URL

    public init(
        deviceCode: String,
        userCode: String,
        verificationURL: URL,
        expiresIn: Int,
        interval: Int
    ) {
        self.deviceCode = deviceCode
        self.expiresIn = expiresIn
        self.interval = interval
        self.userCode = userCode
        self.verificationURL = verificationURL
    }
}
