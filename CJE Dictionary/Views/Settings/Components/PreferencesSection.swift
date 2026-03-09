import SwiftUI

struct PreferencesSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section("Preferences") {
            Toggle(
                "Show icon text in Kanji view",
                isOn: Binding(
                    get: { viewModel.boolValue(for: SettingsKeys.kanjiShowIconText, default: false) },
                    set: { viewModel.setBoolValue($0, for: SettingsKeys.kanjiShowIconText) }
                )
            )

            Toggle(
                "Condensed dictionary result list",
                isOn: Binding(
                    get: { viewModel.boolValue(for: SettingsKeys.dictionaryCondensedList, default: false) },
                    set: { viewModel.setBoolValue($0, for: SettingsKeys.dictionaryCondensedList) }
                )
            )
        }
    }
}
