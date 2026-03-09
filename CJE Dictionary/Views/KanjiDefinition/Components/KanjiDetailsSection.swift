import SwiftUI

struct KanjiDetailsSection: View {
    let info: KanjiInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !info.meaning.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meanings")
                        .font(.headline)
                    Text(info.meaning.joined(separator: "; "))
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Readings")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
                    ForEach(readingEntries) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.values.joined(separator: " • "))
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var readingEntries: [KanjiReadingEntry] {
        KanjiDetailsSectionUtilities.readingEntries(from: info.readings)
    }
}
