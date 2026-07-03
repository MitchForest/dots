import DotsDomain
import DotsUI
import SwiftUI

/// Streak configuration: what counts as a day's writing, and which days
/// count at all. Model-blind — a goal in, changes flow out. Saves as you
/// change (debounced) and on close; there is no Save button.
struct StreakSettingsView: View {
    let goal: StreakGoal
    let onSave: (StreakGoal) -> Void

    @State private var commitTask: Task<Void, Never>?
    @State private var goalDays: Set<Int>
    @State private var isWordGoal: Bool
    @State private var wordText: String

    private static let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    init(goal: StreakGoal, onSave: @escaping (StreakGoal) -> Void) {
        self.goal = goal
        self.onSave = onSave
        _goalDays = State(initialValue: goal.goalDays)
        switch goal.mode {
        case .anyWriting:
            _isWordGoal = State(initialValue: false)
            _wordText = State(initialValue: "300")
        case .words(let target):
            _isWordGoal = State(initialValue: true)
            _wordText = State(initialValue: String(target))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.md) {
            DotsMetaLabel("DAILY GOAL")

            Picker("Daily goal", selection: $isWordGoal) {
                Text("Any writing").tag(false)
                Text("Word count").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if isWordGoal {
                HStack(spacing: DotsSpacing.sm) {
                    Text("At least")
                        .font(DotsTypography.body)
                        .foregroundStyle(DotsColor.Ink.secondary)
                    TextField("300", text: $wordText)
                        .textFieldStyle(.plain)
                        .font(DotsTypography.body)
                        .foregroundStyle(DotsColor.Ink.primary)
                        .frame(width: 56)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, DotsSpacing.xs)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: DotsRadius.sm, style: .continuous)
                                .fill(DotsColor.Surface.control)
                        )
                    Text("words a day")
                        .font(DotsTypography.body)
                        .foregroundStyle(DotsColor.Ink.secondary)
                }
            }

            DotsMetaLabel("GOAL DAYS")

            HStack(spacing: DotsSpacing.xs) {
                ForEach(1...7, id: \.self) { weekday in
                    dayToggle(weekday)
                }
            }
        }
        .padding(DotsSpacing.lg)
        .frame(width: 300)
        .onChange(of: isWordGoal) { scheduleCommit() }
        .onChange(of: wordText) { scheduleCommit() }
        .onChange(of: goalDays) { scheduleCommit() }
        .onChange(of: goal) {
            // An outside change (initial async load, another device) lands
            // in the drafts — unless it's the echo of our own commit.
            guard goal != draftedGoal else { return }
            goalDays = goal.goalDays
            switch goal.mode {
            case .anyWriting:
                isWordGoal = false
            case .words(let target):
                isWordGoal = true
                wordText = String(target)
            }
        }
        .onDisappear {
            commitTask?.cancel()
            commitNow()
        }
    }

    /// The goal as currently drafted, normalized the way commits are: a
    /// word target is at least 1, and no goal days means every day.
    private var draftedGoal: StreakGoal {
        let target = max(1, Int(wordText.trimmingCharacters(in: .whitespaces)) ?? 300)
        return StreakGoal(
            mode: isWordGoal ? .words(target: target) : .anyWriting,
            goalDays: goalDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : goalDays
        )
    }

    private func scheduleCommit() {
        commitTask?.cancel()
        commitTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            commitNow()
        }
    }

    private func commitNow() {
        guard draftedGoal != goal else { return }
        onSave(draftedGoal)
    }

    private func dayToggle(_ weekday: Int) -> some View {
        let isOn = goalDays.contains(weekday)
        return Button {
            if isOn {
                goalDays.remove(weekday)
            } else {
                goalDays.insert(weekday)
            }
        } label: {
            Text(Self.dayLabels[weekday - 1])
                .font(DotsTypography.caption)
                .foregroundStyle(isOn ? DotsColor.Ink.inverse : DotsColor.Ink.secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(isOn ? DotsColor.brand : DotsColor.Surface.control)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isOn ? "Disable" : "Enable") weekday \(weekday)")
    }
}

#Preview {
    StreakSettingsView(goal: StreakGoal(mode: .words(target: 300))) { _ in }
}
