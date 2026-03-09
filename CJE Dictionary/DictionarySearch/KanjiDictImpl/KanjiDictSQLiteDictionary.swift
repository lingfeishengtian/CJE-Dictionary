import Foundation
import SQLite

struct KanjiDictSQLiteDictionary: KanjiDictionaryProtocol {
    let name: String
    let dictionaryType: DictionaryTypeDescriptor
    private let databasePath: String

    init(name: String, type: LanguageToLanguage, databasePath: String) {
        self.name = name
        self.dictionaryType = type.asDescriptor(
            id: name,
            displayName: name,
            backend: .unknown,
            parser: .structured,
            includeInCrossDictionaryLookup: false
        )
        self.databasePath = databasePath
    }

    init(name: String, dictionaryType: DictionaryTypeDescriptor, databasePath: String) {
        self.name = name
        self.dictionaryType = dictionaryType
        self.databasePath = databasePath
    }

    init?(name: String = "kanjidict2", bundle: Bundle = .main) {
        guard let path = Self.resolveDatabasePath(bundle: bundle) else {
            return nil
        }

        let pair = LanguageToLanguage(
            searchLanguage: Language(rawValue: "ja-JP"),
            resultsLanguage: Language(rawValue: "en-US")
        )

        self.init(
            name: name,
            dictionaryType: pair.asDescriptor(
                id: "kanjidict2",
                displayName: name,
                backend: .unknown,
                parser: .structured,
                includeInCrossDictionaryLookup: false
            ),
            databasePath: path
        )
    }

    func searchExact(_ searchString: String) -> DictionaryStreamProtocol {
        DictionaryStream(keys: searchKeys(query: searchString, exactMatch: true))
    }

    func searchPrefix(_ prefix: String) -> DictionaryStreamProtocol {
        DictionaryStream(keys: searchKeys(query: prefix, exactMatch: false))
    }

    func getWord(byId id: AnyHashable) -> Word? {
        let text = String(describing: id)
        return Word(id: text, dictionaryName: name, word: text, readings: [])
    }

    func getWord(fromKey key: SearchResultKey) -> Word? {
        Word(id: key.id, dictionaryName: name, word: key.keyText, readings: key.readings ?? [])
    }

    func getDefinitionGroups(fromKey key: SearchResultKey) async throws -> [DefinitionGroup] {
        guard let kanjiInfo = try getKanjiInfo(fromKey: key) else {
            return []
        }

        let readingText: [String] = kanjiInfo.readings
            .keys
            .sorted()
            .compactMap { kind in
                guard let values = kanjiInfo.readings[kind], !values.isEmpty else { return nil }
                return "\(kind): \(values.joined(separator: ", "))"
            }

        var definitions: [Definition] = kanjiInfo.meaning.map {
            Definition(definition: $0, exampleSentences: [])
        }

        if definitions.isEmpty, !readingText.isEmpty {
            definitions = readingText.map { Definition(definition: $0, exampleSentences: []) }
        }

        if definitions.isEmpty {
            return []
        }

        var tags: [Tag] = []
        if let strokeCount = kanjiInfo.strokeCount {
            tags.append(Tag(shortName: "strokes", longName: "Strokes: \(strokeCount)"))
        }
        if let jlpt = kanjiInfo.jlpt {
            tags.append(Tag(shortName: "jlpt", longName: "JLPT: \(jlpt)"))
        }

        return [DefinitionGroup(tags: tags, definitions: definitions)]
    }

    func getKanjiInfo(fromKey key: SearchResultKey) throws -> KanjiInfo? {
        guard let literal = key.keyText.first.map(String.init) else {
            return nil
        }
        return try loadKanjiInfo(literal: literal)
    }

    private func searchKeys(query: String, exactMatch: Bool) -> [SearchResultKey] {
        guard !query.isEmpty, let connection = openConnection() else {
            return []
        }

        do {
            let sql: String
            let bindings: [Binding?]
            if exactMatch {
                sql = "SELECT literal FROM kanjidic WHERE literal = ? LIMIT 50"
                bindings = [query]
            } else {
                sql = "SELECT literal FROM kanjidic WHERE literal LIKE ? LIMIT 100"
                bindings = ["\(query)%"]
            }

            let statement = try connection.prepare(sql)
            var keys: [SearchResultKey] = []

            for row in try statement.run(bindings) {
                guard let literal = row[0] as? String, !literal.isEmpty else { continue }
                keys.append(
                    SearchResultKey(
                        id: literal,
                        dictionaryName: name,
                        keyText: literal,
                        keyId: Self.stableKeyId(for: literal),
                        readings: []
                    )
                )
            }

            return keys
        } catch {
            print("KanjiDictSQLiteDictionary search error: \(error)")
            return []
        }
    }

    private func loadKanjiInfo(literal: String) throws -> KanjiInfo? {
        guard let connection = openConnection() else {
            return nil
        }

        let sql = "SELECT literal, jlpt, grade, freq, stroke_count, reading, meaning, nanori FROM kanjidic WHERE literal = ? LIMIT 1"
        let statement = try connection.prepare(sql)

        for row in try statement.run([literal]) {
            guard let literalValue = row[0] as? String,
                  let character = literalValue.first
            else {
                continue
            }

            let jlpt = row[1] as? Int64
            let grade = row[2] as? Int64
            let frequency = row[3] as? Int64
            let strokeCount = row[4] as? Int64
            let readingRaw = row[5] as? String
            let meaningRaw = row[6] as? String
            let nanoriRaw = row[7] as? String

            let meanings = Self.parseStringArray(meaningRaw)
            var readings = Self.parseReadings(readingRaw)
            let nanori = Self.parseStringArray(nanoriRaw)
            if !nanori.isEmpty {
                readings["nanori"] = nanori
            }

            return KanjiInfo(
                kanjiCharacter: character,
                jlpt: jlpt.map(Int.init),
                grade: grade.map(Int.init),
                frequency: frequency.map(Int.init),
                readings: readings,
                strokeCount: strokeCount.map(Int.init),
                meaning: meanings
            )
        }

        return nil
    }

    private func openConnection() -> Connection? {
        do {
            return try Connection(databasePath)
        } catch {
            print("KanjiDictSQLiteDictionary connection error: \(error)")
            return nil
        }
    }

    private static func parseReadings(_ rawValue: String?) -> [String: [String]] {
        let payload = parseJSONArray(rawValue)
        var readings: [String: [String]] = [:]

        for item in payload {
            guard let dict = item as? [String: Any],
                  let type = dict["r_type"] as? String,
                  let value = dict["$t"] as? String
            else {
                continue
            }
            readings[type, default: []].append(value)
        }

        return readings
    }

    private static func parseStringArray(_ rawValue: String?) -> [String] {
        parseJSONArray(rawValue).compactMap { $0 as? String }
    }

    private static func parseJSONArray(_ rawValue: String?) -> [Any] {
        guard let rawValue, !rawValue.isEmpty else { return [] }

        let utf16Data = rawValue.data(using: .utf16)
        let utf8Data = rawValue.data(using: .utf8)

        if let utf16Data,
           let json = try? JSONSerialization.jsonObject(with: utf16Data) as? [Any] {
            return json
        }

        if let utf8Data,
           let json = try? JSONSerialization.jsonObject(with: utf8Data) as? [Any] {
            return json
        }

        return []
    }

    private static func stableKeyId(for value: String) -> Int64 {
        Int64(bitPattern: UInt64(truncatingIfNeeded: value.hashValue))
    }

    private static func resolveDatabasePath(bundle: Bundle) -> String? {
        if let bundledPath = bundle.path(forResource: "KANJIDIC2_cleaned", ofType: "db") {
            return bundledPath
        }

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let candidates = [
            documents.appendingPathComponent("kanjidict2.db").path,
            documents.appendingPathComponent("KANJIDIC2_cleaned.db").path,
            documents.appendingPathComponent("kanjidict2").appendingPathComponent("kanjidict2.db").path,
            documents.appendingPathComponent("kanjidict2").appendingPathComponent("KANJIDIC2_cleaned.db").path
        ]

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) })
    }
}
