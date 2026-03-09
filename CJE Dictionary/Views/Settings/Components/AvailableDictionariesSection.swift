import SwiftUI

struct AvailableDictionariesSection: View {
    let items: [DictionaryManifestItem]
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
