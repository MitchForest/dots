import DotsDomain
import DotsEngine
import Foundation
import Testing

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

@Suite("FrontmatterBlock")
struct FrontmatterBlockTests {
    @Test("Split and join round-trip losslessly")
    func roundTrip() {
        let contents = "---\nid: 1\ntitle: Hi\n---\n\n# Body\n\nProse."
        let parts = FrontmatterBlock.split(contents)

        #expect(parts.frontmatter == "---\nid: 1\ntitle: Hi\n---\n\n")
        #expect(parts.body == "# Body\n\nProse.")
        #expect(FrontmatterBlock.join(frontmatter: parts.frontmatter, body: parts.body) == contents)
    }

    @Test("No frontmatter passes through untouched")
    func noFrontmatter() {
        let parts = FrontmatterBlock.split("# Just prose")
        #expect(parts.frontmatter.isEmpty)
        #expect(parts.body == "# Just prose")
    }

    @Test("Unclosed fence is treated as body")
    func unclosedFence() {
        let parts = FrontmatterBlock.split("---\nid: 1\nno closing fence")
        #expect(parts.frontmatter.isEmpty)
        #expect(parts.body == "---\nid: 1\nno closing fence")
    }
}

@Suite("WritingActivity")
struct WritingActivityTests {
    @Test("Intensities are oldest-first with today last")
    func intensitiesShape() {
        let calendar = utcCalendar()
        let today = Date(timeIntervalSince1970: 100 * 86_400)
        let todayStart = calendar.startOfDay(for: today)
        let values = WritingActivity.intensities(
            byDay: [todayStart: 3],
            today: today,
            calendar: calendar
        )

        #expect(values.count == 84)
        #expect(values.last == 1)
        #expect(values.dropLast().allSatisfy { $0 == 0 })
    }

    @Test("Streak counts completed goal days; a pending today doesn't break it")
    func streak() {
        let calendar = utcCalendar()
        let today = Date(timeIntervalSince1970: 100 * 86_400)
        let day: (Int) -> Date = { offset in
            calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: today))!
        }
        let goal = StreakGoal()
        let stats: ([Date: Int]) -> VaultStats = { VaultStats(activityByDay: $0) }

        #expect(WritingActivity.streak(stats: stats([day(0): 1, day(1): 2]), goal: goal, today: today, calendar: calendar) == 2)
        #expect(WritingActivity.streak(stats: stats([day(1): 1, day(2): 1]), goal: goal, today: today, calendar: calendar) == 2)
        #expect(WritingActivity.streak(stats: stats([day(2): 1]), goal: goal, today: today, calendar: calendar) == 0)
        #expect(WritingActivity.streak(stats: stats([:]), goal: goal, today: today, calendar: calendar) == 0)
    }

    @Test("Word goals require the target; rest days pass through")
    func wordGoal() {
        let calendar = utcCalendar()
        let today = Date(timeIntervalSince1970: 100 * 86_400)
        let todayStart = calendar.startOfDay(for: today)
        let goal = StreakGoal(mode: .words(target: 300))

        let short = VaultStats(wordsByDay: [todayStart: 100])
        let enough = VaultStats(wordsByDay: [todayStart: 350])

        #expect(!WritingActivity.isComplete(on: today, stats: short, goal: goal, calendar: calendar))
        #expect(WritingActivity.isComplete(on: today, stats: enough, goal: goal, calendar: calendar))

        let weekday = calendar.component(.weekday, from: todayStart)
        let restGoal = StreakGoal(mode: .words(target: 300), goalDays: Set(1...7).subtracting([weekday]))
        #expect(WritingActivity.isComplete(on: today, stats: short, goal: restGoal, calendar: calendar))
    }
}
