import SwiftUI

struct InstallFromURLSection: View {
    @Binding var dictionaryURLInput: String
    let onInstallCustom: () async -> Void

    var body: some View {
        Section("Install from URL") {
            TextField("https://...", text: $dictionaryURLInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await onInstallCustom() }
            } label: {
                Label("Install custom dictionary", systemImage: "link.badge.plus")
            }
        }
    }
}
