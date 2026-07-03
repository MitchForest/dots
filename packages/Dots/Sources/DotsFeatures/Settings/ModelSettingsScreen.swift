import ComposableArchitecture2
import DotsDomain
import DotsUI
import SwiftUI

/// The AI sections of the Settings form: pick the brain, see whether it's
/// ready, hold your own key.
struct ModelSettingsSectionsView: View {
    @Bindable var store: StoreOf<ModelSettings>

    var body: some View {
        Section("AI") {
            Picker("Model", selection: providerBinding) {
                ForEach(ModelProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.radioGroup)

            availabilityRow
        }

        if store.provider == .claude {
            Section {
                claudeKeyRow
            } footer: {
                Text(
                    """
                    Text you select is sent to Anthropic only when you \
                    invoke an AI action — nothing leaves this Mac \
                    otherwise. Your key is stored in the Keychain.
                    """
                )
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Ink.muted)
            }
        } else {
            Section {
                EmptyView()
            } footer: {
                Text("The on-device model runs entirely on this Mac. Nothing is ever sent anywhere.")
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.muted)
            }
        }
    }

    private var providerBinding: Binding<ModelProvider> {
        Binding(
            get: { store.provider },
            set: { store.send(.providerSelected($0)) }
        )
    }

    @ViewBuilder private var availabilityRow: some View {
        HStack(spacing: DotsSpacing.xs) {
            switch store.selectedAvailability {
            case .available:
                Circle()
                    .fill(DotsColor.Accent.green)
                    .frame(width: 8, height: 8)
                Text("Ready")
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.secondary)
            case .unavailable(let reason):
                Circle()
                    .fill(DotsColor.Accent.orange)
                    .frame(width: 8, height: 8)
                Text(reason)
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.secondary)
            case nil:
                Circle()
                    .fill(DotsColor.Ink.muted)
                    .frame(width: 8, height: 8)
                Text("Checking…")
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.muted)
            }
        }
    }

    @ViewBuilder private var claudeKeyRow: some View {
        if store.hasStoredKey {
            HStack {
                Text("API key stored in Keychain")
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.secondary)
                Spacer()
                Button("Remove") {
                    store.send(.keyCleared)
                }
            }
        } else {
            HStack {
                SecureField("Anthropic API key", text: $store.keyDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { store.send(.keySaved) }
                Button("Save") {
                    store.send(.keySaved)
                }
                .disabled(store.keyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

#Preview {
    Form {
        ModelSettingsSectionsView(
            store: Store(initialState: ModelSettings.State()) {
                ModelSettings()
            }
        )
    }
    .formStyle(.grouped)
    .frame(width: 440)
}
