import SwiftUI

struct AISettingsView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ScreenScaffold(
            title: "AI",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            AppCard {
                Picker("Provider", selection: providerBinding) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue.capitalized).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Assistant instructions", text: instructionsBinding, axis: .vertical)
                    .lineLimit(5...10)
                    .textFieldStyle(AppTextFieldStyle())
            }
        }
        .navigationTopDividerHidden()
        .accessibilityIdentifier("ai-settings-screen")
    }

    private var providerBinding: Binding<AIProvider> {
        Binding {
            store.snapshot.settings.aiProvider
        } set: { provider in
            var settings = store.snapshot.settings
            settings.aiProvider = provider
            store.updateSettings(settings)
        }
    }

    private var instructionsBinding: Binding<String> {
        Binding {
            store.snapshot.settings.aiInstructions
        } set: { instructions in
            var settings = store.snapshot.settings
            settings.aiInstructions = instructions
            store.updateSettings(settings)
        }
    }
}
