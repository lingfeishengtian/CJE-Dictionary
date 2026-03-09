import Foundation

enum SearchDictionaryUtilities {
    static func navigationTitle(for dictionaries: [any DictionaryProtocol]) -> String {
        if dictionaries.count == 1 {
            return dictionaries[0].name
        }
        return "Dictionaries"
    }

    static func buildPrioritizedQueries(from input: String) -> [String] {
        let normalizedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedInput.isEmpty {
            return []
        }

        var queries: [String] = []

        func appendUnique(_ candidate: String?) {
            guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return
            }
            if !queries.contains(value) {
                queries.append(value)
            }
        }

        let hiragana = normalizedInput.applyingTransform(.latinToHiragana, reverse: false)
            ?? normalizedInput.applyingTransform(.hiraganaToKatakana, reverse: true)
        let katakana = hiragana?.applyingTransform(.hiraganaToKatakana, reverse: false)
            ?? normalizedInput.applyingTransform(.latinToKatakana, reverse: false)
            ?? normalizedInput.applyingTransform(.hiraganaToKatakana, reverse: false)
        let romaji = normalizedInput
            .applyingTransform(.toLatin, reverse: false)?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")

        appendUnique(normalizedInput)
        appendUnique(hiragana)
        appendUnique(katakana)
        appendUnique(romaji)

        return queries
    }

    static func buildSearchStreams(
        prioritizedQueries: [String],
        dictionaries: [any DictionaryProtocol]
    ) -> [DictionaryStreamProtocol] {
        var streams: [DictionaryStreamProtocol] = []
        for dictionary in dictionaries {
            for query in prioritizedQueries {
                streams.append(dictionary.searchPrefix(query))
            }
        }
        return streams
    }
}
