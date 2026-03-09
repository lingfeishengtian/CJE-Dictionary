import SwiftUI

struct KanjiHeaderCard: View {
    let key: SearchResultKey
    let kanjiInfo: KanjiInfo?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(key.keyText)
                .font(.system(size: 82, weight: .regular))
                .frame(minWidth: 88, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("KANJIDICT")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let readings = key.readings, !readings.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Readings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(readings.joined(separator: " • "))
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                }

                if let kanjiInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if let strokeCount = kanjiInfo.strokeCount {
                                basicInfoBlock(label: "Strokes", value: String(strokeCount))
                            }
                            if let jlpt = kanjiInfo.jlpt {
                                basicInfoBlock(label: "JLPT", value: String(jlpt))
                            }
                        }

                        HStack(spacing: 6) {
                            if let grade = kanjiInfo.grade {
                                basicInfoBlock(label: "Grade", value: String(grade))
                            }
                            if let frequency = kanjiInfo.frequency {
                                basicInfoBlock(label: "Frequency", value: String(frequency))
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func basicInfoBlock(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
