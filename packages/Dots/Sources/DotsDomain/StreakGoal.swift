/// The writer's daily-streak contract, persisted in `.dots/settings.json` so
/// it travels with the vault. `goalDays` uses `Calendar` weekday numbers
/// (1 = Sunday … 7 = Saturday); non-goal days neither extend nor break a
/// streak.
public struct StreakGoal: Codable, Hashable, Sendable {
    public enum Mode: Codable, Hashable, Sendable {
        case anyWriting
        case words(target: Int)
    }

    public var goalDays: Set<Int>
    public var mode: Mode

    public init(mode: Mode = .anyWriting, goalDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]) {
        self.goalDays = goalDays
        self.mode = mode
    }
}
