import SwiftUI

struct InstalledDictionariesSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    let installedRecords: [DictionaryID: DictionaryInstallRecord]
    let orderedInstalledRecords: [DictionaryInstallRecord]

    var body: some View {
        Section("Installed Dictionaries") {
            Text("These dictionaries are active in search and definitions. Reorder to change search priority.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if orderedInstalledRecords.isEmpty {
                Text("No dictionaries installed yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(orderedInstalledRecords, id: \.id) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.id.rawValue)

                            Text("v\(record.installedVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !viewModel.canRemove(record.id) {
                                Text("Required dictionary")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if viewModel.canRemove(record.id) {
                            Button(role: .destructive) {
                                Task { await viewModel.remove(record.id) }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove { source, destination in
                    viewModel.moveInstalledDictionaries(
                        from: source,
                        to: destination,
                        installedRecords: installedRecords
                    )
                }
            }
        }
    }
}
