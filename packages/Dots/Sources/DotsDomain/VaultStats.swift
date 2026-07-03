public import Foundation

/// Home-screen vault summary: counts plus per-day activity (dot captures and
/// draft touches, keyed by start-of-day).
public struct VaultStats: Equatable, Sendable {
    public var activityByDay: [Date: Int]
    public var dotCount: Int
    public var draftCount: Int
    public var wordsByDay: [Date: Int]

    public init(
        activityByDay: [Date: Int] = [:],
        dotCount: Int = 0,
        draftCount: Int = 0,
        wordsByDay: [Date: Int] = [:]
    ) {
        self.activityByDay = activityByDay
        self.dotCount = dotCount
        self.draftCount = draftCount
        self.wordsByDay = wordsByDay
    }
}
