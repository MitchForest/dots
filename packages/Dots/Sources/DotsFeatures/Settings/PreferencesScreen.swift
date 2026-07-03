public import ComposableArchitecture2
public import SwiftUI
import DotsDomain
import DotsUI
import UniformTypeIdentifiers

/// The Settings window: Vault · AI · Writing goal, one calm form. Every row
/// earned its place — everything else Dots decides for you.
public struct PreferencesScreen: View {
    @Bindable private var store: StoreOf<Preferences>

    @State private var isPickingVault = false

    public init(store: StoreOf<Preferences>) {
        self.store = store
    }

    public var body: some View {
        Form {
            vaultSection

            ModelSettingsSectionsView(store: store.scope(\.model, action: \.model))

            intakeSection

            goalSection
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .navigationTitle("Settings")
        .fileImporter(
            isPresented: $isPickingVault,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                store.send(.vaultChosen(url))
            }
        }
    }

    private var vaultSection: some View {
        Section("Vault") {
            HStack(spacing: DotsSpacing.sm) {
                Text(store.vault?.path() ?? "No vault yet — open Dots to create one.")
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                Button("Reveal") {
                    store.send(.revealVaultTapped)
                }
                .disabled(store.vault == nil)

                Button("Switch…") {
                    isPickingVault = true
                }
            }
        }
    }

    private var intakeSection: some View {
        Section {
            Toggle("Draft ideas from captures", isOn: intakeBinding)
        } footer: {
            Text(
                """
                New sources are distilled into proposed ideas you review in \
                the ideas list. With Claude selected, this sends captured \
                articles to Anthropic in the background. Turning it off \
                keeps captures as plain sources; anything already proposed \
                stays reviewable.
                """
            )
            .font(DotsTypography.footnote)
            .foregroundStyle(DotsColor.Ink.muted)
        }
    }

    private var goalSection: some View {
        Section("Writing goal") {
            // The editor syncs itself from `goal` and saves as you change;
            // no recreation, so typing in the target field keeps focus.
            StreakSettingsView(goal: store.streakGoal) { goal in
                store.send(.goalChanged(goal))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var intakeBinding: Binding<Bool> {
        Binding(
            get: { store.isIntakeEnabled },
            set: { store.send(.intakeToggled($0)) }
        )
    }
}

#Preview {
    PreferencesScreen(
        store: Store(initialState: Preferences.State()) {
            Preferences()
        }
    )
    .frame(height: 640)
}
