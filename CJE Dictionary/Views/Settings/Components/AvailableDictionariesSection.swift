import SwiftUI

struct AvailableDictionariesSection: View {
    let items: [DictionaryManifestItem]
    let installedIDs: Set<DictionaryID>
    let onInstall: (DictionaryID) -> Void

    var body: some View {
        Section("Available Dictionaries") {
            ForEach(items, id: \.id) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayName)
                        Text("v\(item.version) • \(item.artifactType.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if installedIDs.contains(item.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            onInstall(item.id)
                        } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
