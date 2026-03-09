import Foundation

struct CrossDictionaryOption: Identifiable {
    let id: String
    let name: String
    let dictionary: any DictionaryProtocol
}

struct CrossDictionaryCandidate: Identifiable {
    let id: String
    let key: SearchResultKey
    let dictionary: any DictionaryProtocol
    let matchedReadingsCount: Int
    let totalReadingsCount: Int

    var confidence: Double {
        guard totalReadingsCount > 0 else { return 0 }
        return Double(matchedReadingsCount) / Double(totalReadingsCount)
    }

    var confidenceText: String {
        let percent = Int((confidence * 100).rounded())
        return "\(percent)%"
    }

    var confidenceLevel: String {
        switch confidence {
        case 0.8...:
            return "High"
        case 0.5...:
            return "Medium"
        default:
            return "Low"
        }
    }
}

enum CrossDictionarySearchUtility {
    static func makeOptions(
        key: SearchResultKey,
        currentDictionary: (any DictionaryProtocol)?
    ) -> [CrossDictionaryOption] {
        createAvailableDictionaries().filter { candidate in
            candidate.dictionaryType.includeInCrossDictionaryLookup
            && candidate.name != key.dictionaryName
            && candidate.dictionaryType.id != currentDictionary?.dictionaryType.id
        }.map {
            CrossDictionaryOption(
                id: $0.dictionaryType.id,
                name: $0.name,
                dictionary: $0
            )
        }
    }

    static func buildCandidates(
        for dictionary: any DictionaryProtocol,
        key: SearchResultKey
    ) -> [CrossDictionaryCandidate] {
        let readingSet = Set((key.readings ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })

        guard !readingSet.isEmpty else {
            return []
        }

        let totalReadingsCount = readingSet.count
        let readings = Array(readingSet)

        var matchesByWord: [String: (SearchResultKey, Set<String>)] = [:]

        for reading in readings {
            var exactStream = dictionary.searchExact(reading)
            let exactMatches = exactStream.toArray()

            var seenForReading: Set<String> = []

            for exactKey in exactMatches {
                let wordKey = "\(dictionary.dictionaryType.id)|\(exactKey.keyText)|\(exactKey.id)"
                if !seenForReading.insert(wordKey).inserted {
                    continue
                }

                var entry = matchesByWord[wordKey] ?? (exactKey, Set<String>())
                entry.1.insert(reading)
                matchesByWord[wordKey] = entry
            }
        }

        var candidates: [CrossDictionaryCandidate] = []
        for (wordID, value) in matchesByWord {
            let matchedReadingsCount = value.1.count
            guard matchedReadingsCount > 0 else { continue }

            candidates.append(
                CrossDictionaryCandidate(
                    id: wordID,
                    key: value.0,
                    dictionary: dictionary,
                    matchedReadingsCount: matchedReadingsCount,
                    totalReadingsCount: totalReadingsCount
                )
            )
        }

        candidates.sort {
            if $0.matchedReadingsCount != $1.matchedReadingsCount {
                return $0.matchedReadingsCount > $1.matchedReadingsCount
            }
            if $0.confidence != $1.confidence {
                return $0.confidence > $1.confidence
            }
            return $0.key.keyText.localizedStandardCompare($1.key.keyText) == .orderedAscending
        }

        return candidates
    }

    static func loadDefinition(for candidate: CrossDictionaryCandidate) async -> DefinitionContentLoadResult {
        await DefinitionContentLoadUtility.loadDefinition(
            dictionary: candidate.dictionary,
            key: candidate.key
        )
    }
}
