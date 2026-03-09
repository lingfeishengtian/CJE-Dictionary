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
    let matchedReadingsComplexityScore: Int
    let totalReadingsCount: Int

    var confidence: Double {
        guard totalReadingsCount > 0 else { return 0 }
        let baseConfidence = Double(matchedReadingsCount) / Double(totalReadingsCount)
        let complexityExcess = max(0, matchedReadingsComplexityScore - matchedReadingsCount)
        let complexityBonus = min(0.08, Double(complexityExcess) * 0.01)
        return min(1, baseConfidence + complexityBonus)
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
    private static let maxExactMatchesPerReading = 10
    private static let maxCandidatesPerDictionary = 100

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
        let readingSet = normalizedOriginalReadings(from: key)

        guard !readingSet.isEmpty else {
            return []
        }

        let totalReadingsCount = readingSet.count
        let readings = Array(readingSet)

        var matchesByWord: [String: (SearchResultKey, Set<String>)] = [:]

        for reading in readings {
            var exactStream = dictionary.searchExact(reading)
            let exactMatches = Array(exactStream.toArray().prefix(maxExactMatchesPerReading))

            var seenForReading: Set<String> = []

            for exactKey in exactMatches {
                let wordKey = stableCandidateID(for: exactKey, dictionary: dictionary)
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
            let matchedReadingsComplexityScore = value.1.reduce(0) { partial, reading in
                partial + readingComplexityScore(for: reading)
            }

            candidates.append(
                CrossDictionaryCandidate(
                    id: wordID,
                    key: value.0,
                    dictionary: dictionary,
                    matchedReadingsCount: matchedReadingsCount,
                    matchedReadingsComplexityScore: matchedReadingsComplexityScore,
                    totalReadingsCount: totalReadingsCount
                )
            )

            if candidates.count >= maxCandidatesPerDictionary {
                break
            }
        }

        candidates.sort {
            if $0.matchedReadingsCount != $1.matchedReadingsCount {
                return $0.matchedReadingsCount > $1.matchedReadingsCount
            }
            if $0.matchedReadingsComplexityScore != $1.matchedReadingsComplexityScore {
                return $0.matchedReadingsComplexityScore > $1.matchedReadingsComplexityScore
            }
            if $0.confidence != $1.confidence {
                return $0.confidence > $1.confidence
            }
            return $0.key.keyText.localizedStandardCompare($1.key.keyText) == .orderedAscending
        }

        return candidates
    }

    private static func normalizedOriginalReadings(from key: SearchResultKey) -> Set<String> {
        let normalized = Set((key.readings ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })

        if !normalized.isEmpty {
            return normalized
        }

        let fallback = key.keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.isEmpty {
            return []
        }

        return [fallback]
    }

    private static func stableCandidateID(
        for key: SearchResultKey,
        dictionary: any DictionaryProtocol
    ) -> String {
        let normalizedID = key.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let idPart = normalizedID.isEmpty ? key.keyText : normalizedID
        return "\(dictionary.dictionaryType.id)|\(idPart)|\(key.keyId)|\(key.keyText)"
    }

    private static func readingComplexityScore(for reading: String) -> Int {
        var score = 0

        for scalar in reading.unicodeScalars {
            if scalar.properties.isIdeographic {
                score += 3
                continue
            }

            switch scalar.value {
            case 0x3040...0x309F: // Hiragana
                score += 1
            case 0x30A0...0x30FF: // Katakana
                score += 1
            case 0x0030...0x0039, 0xFF10...0xFF19: // ASCII/fullwidth digits
                score += 1
            case 0x0041...0x005A, 0x0061...0x007A, 0xFF21...0xFF3A, 0xFF41...0xFF5A: // ASCII/fullwidth latin
                score += 1
            default:
                score += 0
            }
        }

        return score
    }

    static func loadDefinition(for candidate: CrossDictionaryCandidate) async -> DefinitionContentLoadResult {
        await DefinitionContentLoadUtility.loadDefinition(
            dictionary: candidate.dictionary,
            key: candidate.key
        )
    }
}
