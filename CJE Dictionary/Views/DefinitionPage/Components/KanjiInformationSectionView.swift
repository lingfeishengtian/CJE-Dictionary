import SwiftUI

struct KanjiInformationSectionView: View {
    let matches: [SearchResultKey]
    let kanjiInfosByCharacter: [String: KanjiInfo]
    let dictionary: (any DictionaryProtocol)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Kanji Information"))
                .font(.headline)

            ForEach(matches, id: \.id) { kanjiKey in
                NavigationLink {
                    KanjiDefinition(key: kanjiKey, dictionary: dictionary)
                } label: {
                    kanjiRow(for: kanjiKey)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func kanjiRow(for kanjiKey: SearchResultKey) -> some View {
        let info = kanjiInfosByCharacter[kanjiKey.keyText]

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Text(kanjiKey.keyText)
                    .font(.system(size: 30, weight: .regular))

                VStack(alignment: .leading, spacing: 4) {
                    if let info, !info.meaning.isEmpty {
                        Text(info.meaning.prefix(3).joined(separator: "; "))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    } else if let readings = kanjiKey.readings, !readings.isEmpty {
                        Text(readings.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    if let info {
                        Text(kanjiMetaLine(info: info))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func kanjiMetaLine(info: KanjiInfo) -> String {
        var items: [String] = []
        if let strokeCount = info.strokeCount {
            items.append("Strokes \(strokeCount)")
        }
        if let jlpt = info.jlpt {
            items.append("JLPT \(jlpt)")
        }
        if let grade = info.grade {
            items.append("Grade \(grade)")
        }
        return items.joined(separator: "  •  ")
    }
}
