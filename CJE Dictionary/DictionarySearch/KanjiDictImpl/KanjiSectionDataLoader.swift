import Foundation

enum KanjiSectionDataLoader {
    static func loadMatches(from key: SearchResultKey, using dictionary: (any DictionaryProtocol)?) -> [SearchResultKey] {
        guard let dictionary else {
            return []
        }

        var seen: Set<String> = []
        var output: [SearchResultKey] = []

        for kanjiCharacter in extractUniqueKanji(from: key) {
            var stream = dictionary.searchExact(kanjiCharacter)
            if let first = stream.next(), seen.insert(first.keyText).inserted {
                output.append(first)
            }
        }

        return output
    }

    static func loadInfos(for keys: [SearchResultKey], using dictionary: (any DictionaryProtocol)?) -> [String: KanjiInfo] {
        guard let kanjiDictionary = dictionary as? any KanjiDictionaryProtocol else {
            return [:]
        }

        var output: [String: KanjiInfo] = [:]
        for key in keys {
            if let info = try? kanjiDictionary.getKanjiInfo(fromKey: key) {
                output[key.keyText] = info
            }
        }

        return output
    }

    static func extractUniqueKanji(from key: SearchResultKey) -> [String] {
        let sourceText = [
            key.keyText,
            key.readings?.joined(separator: " ") ?? ""
        ].joined(separator: " ")

        var ordered: [String] = []
        var seen: Set<String> = []

        for character in sourceText where character.isKanjiCharacter {
            let value = String(character)
            if seen.insert(value).inserted {
                ordered.append(value)
            }
        }

        return ordered
    }
}

private extension Character {
    var isKanjiCharacter: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF, 0x20000...0x2A6DF, 0x2A700...0x2B73F, 0x2B740...0x2B81F, 0x2B820...0x2CEAF:
                return true
            default:
                return false
            }
        }
    }
}
