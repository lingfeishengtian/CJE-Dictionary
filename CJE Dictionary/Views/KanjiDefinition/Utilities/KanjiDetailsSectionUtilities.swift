import Foundation

struct KanjiReadingEntry: Identifiable, Hashable {
    let key: String
    let label: String
    let values: [String]

    var id: String { key }
}

enum KanjiDetailsSectionUtilities {
    static func readingEntries(from readings: [String: [String]]) -> [KanjiReadingEntry] {
        sortedReadingKeys(from: readings).compactMap { key in
            guard let values = readings[key], !values.isEmpty else {
                return nil
            }
            return KanjiReadingEntry(key: key, label: readingLabel(for: key), values: values)
        }
    }

    private static func sortedReadingKeys(from readings: [String: [String]]) -> [String] {
        readings.keys.sorted { lhs, rhs in
            let left = readingPriority(for: lhs)
            let right = readingPriority(for: rhs)
            if left == right {
                return readingLabel(for: lhs) < readingLabel(for: rhs)
            }
            return left < right
        }
    }

    private static func readingPriority(for key: String) -> Int {
        switch key.lowercased() {
        case "ja_on": return 0
        case "ja_kun": return 1
        case "nanori": return 2
        case "pinyin": return 3
        case "korean_h": return 4
        case "korean_r": return 5
        case "vietnam": return 6
        default: return 99
        }
    }

    private static func readingLabel(for key: String) -> String {
        switch key.lowercased() {
        case "ja_on": return "On'yomi"
        case "ja_kun": return "Kun'yomi"
        case "nanori": return "Nanori"
        case "pinyin": return "Pinyin"
        case "korean_h": return "Korean (Hangul)"
        case "korean_r": return "Korean (Romanized)"
        case "vietnam": return "Vietnamese"
        default:
            return key
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }
}
