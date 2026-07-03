public import Foundation

/// ULID generation (https://github.com/ulid/spec): 48-bit millisecond
/// timestamp + 80 bits of randomness, Crockford base32, 26 characters,
/// lexicographically sortable. Time and randomness are injected so ids are
/// deterministic under test.
public enum ULID {
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    public static func generate(
        timestamp: Date,
        using generator: inout some RandomNumberGenerator
    ) -> String {
        let millis = UInt64(max(0, timestamp.timeIntervalSince1970) * 1000)
        var characters: [Character] = []
        characters.reserveCapacity(26)
        for shift in stride(from: 45, through: 0, by: -5) {
            characters.append(Self.alphabet[Int((millis >> UInt64(shift)) & 0x1F)])
        }
        for _ in 0..<16 {
            characters.append(Self.alphabet[Int(generator.next() & 0x1F)])
        }
        return String(characters)
    }
}
