public import DotsDomain
public import Foundation

/// Pure math for the Home streak: contribution intensities, goal-day
/// completion, and streak length under the writer's `StreakGoal`.
public enum WritingActivity {
    /// Whether the goal is satisfied on `date`. Non-goal days are rest days
    /// and always count as complete.
    public static func isComplete(
        on date: Date,
        stats: VaultStats,
        goal: StreakGoal,
        calendar: Calendar
    ) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard goal.goalDays.contains(calendar.component(.weekday, from: day)) else { return true }
        switch goal.mode {
        case .anyWriting:
            return stats.activityByDay[day, default: 0] > 0 || stats.wordsByDay[day, default: 0] > 0
        case .words(let target):
            return stats.wordsByDay[day, default: 0] >= target
        }
    }

    /// Completed goal days in a row ending today. Rest days pass through;
    /// an incomplete *today* doesn't break yesterday's run — it's pending.
    public static func streak(
        stats: VaultStats,
        goal: StreakGoal,
        today: Date,
        calendar: Calendar
    ) -> Int {
        var cursor = calendar.startOfDay(for: today)
        var length = 0
        var isFirstDay = true
        // Bounded walk: a decade of days is beyond any honest streak.
        for _ in 0..<3660 {
            let isGoalDay = goal.goalDays.contains(calendar.component(.weekday, from: cursor))
            if isGoalDay {
                if isComplete(on: cursor, stats: stats, goal: goal, calendar: calendar) {
                    length += 1
                } else if isFirstDay {
                    // Today is still pending, not broken.
                } else {
                    break
                }
            }
            isFirstDay = false
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return length
    }
    /// Oldest → newest intensities for the trailing `weeks` of days ending
    /// today. Intensity is `count / 3` clamped to 1 — three captures or
    /// touched drafts reads as a full cell.
    public static func intensities(
        byDay counts: [Date: Int],
        today: Date,
        calendar: Calendar,
        weeks: Int = 12
    ) -> [Double] {
        let todayStart = calendar.startOfDay(for: today)
        let dayCount = weeks * 7
        return (0..<dayCount).map { index in
            let offset = dayCount - 1 - index
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else {
                return 0
            }
            let count = counts[day] ?? 0
            return min(1, Double(count) / 3)
        }
    }

}
