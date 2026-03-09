import Foundation

protocol DictionaryRegistry {
    func createAvailableDictionaries() -> [any DictionaryProtocol]
}

struct DefaultDictionaryRegistry: DictionaryRegistry {
    func createAvailableDictionaries() -> [any DictionaryProtocol] {
        var dictionaries: [any DictionaryProtocol] = []
        var usedNames: Set<String> = []

        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        for dictionary in discoverMetadataDictionaries(in: documentsDirectory, fileManager: fileManager, usedNames: &usedNames) {
            dictionaries.append(dictionary)
        }

        return applySavedDictionarySearchOrder(to: dictionaries)
    }

    private func discoverMetadataDictionaries(in documentsDirectory: URL, fileManager: FileManager, usedNames: inout Set<String>) -> [any DictionaryProtocol] {
        var results: [any DictionaryProtocol] = []

        guard let enumerator = fileManager.enumerator(
            at: documentsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let url as URL in enumerator {
            guard url.lastPathComponent == "dictionary.json" else { continue }

            do {
                let metadata = try LocalDictionaryMetadataDecoder.decode(from: url)
                let directory = url.deletingLastPathComponent()
                let dictionaryID = dictionaryIdentifier(
                    documentsDirectory: documentsDirectory,
                    dictionaryDirectory: directory,
                    metadataID: metadata.id
                )
                if let dictionary = makeDictionary(from: metadata, dictionaryID: dictionaryID, in: directory, usedNames: &usedNames, fileManager: fileManager) {
                    results.append(dictionary)
                }
            } catch {
                continue
            }
        }

        return results
    }

    private func makeDictionary(
        from metadata: LocalDictionaryMetadata,
        dictionaryID: String,
        in directory: URL,
        usedNames: inout Set<String>,
        fileManager: FileManager
    ) -> (any DictionaryProtocol)? {
        let dictionaryName = uniqueDictionaryName(for: metadata.displayName, usedNames: &usedNames)
        let pair = languagePair(searchCode: metadata.searchLanguage, resultsCode: metadata.resultsLanguage)

        switch metadata.backend {
        case .mdictOptimized:
            return makeMdictDictionary(name: dictionaryName, dictionaryID: dictionaryID, pair: pair, metadata: metadata, directory: directory, fileManager: fileManager)
        case .realmMongo:
            return makeRealmDictionary(name: dictionaryName, dictionaryID: dictionaryID, pair: pair, metadata: metadata, directory: directory, fileManager: fileManager)
        case .kanjiSqlite, .sqlite:
            return makeKanjiSqliteDictionary(name: dictionaryName, dictionaryID: dictionaryID, pair: pair, metadata: metadata, directory: directory, fileManager: fileManager)
        }
    }

    private func makeMdictDictionary(
        name: String,
        dictionaryID: String,
        pair: LanguageToLanguage,
        metadata: LocalDictionaryMetadata,
        directory: URL,
        fileManager: FileManager
    ) -> MdictOptimizedDictionary? {
        guard let fstPath = resolvedPath(in: directory, files: metadata.files, keys: ["fst"], fileManager: fileManager),
              let readingsPath = resolvedPath(in: directory, files: metadata.files, keys: ["readings", "rd"], fileManager: fileManager),
              let recordPath = resolvedPath(in: directory, files: metadata.files, keys: ["record", "def"], fileManager: fileManager),
              let optimized = MdictOptimizedManager.createOptimized(
                fromBundle: "",
                fstPath: fstPath,
                readingsPath: readingsPath,
                recordPath: recordPath
              )
        else {
            return nil
        }

        return MdictOptimizedDictionary(
            name: name,
            dictionaryType: pair.asDescriptor(
                id: dictionaryID,
                displayName: name,
                backend: .mdictOptimized,
                parser: .scriptJS
            ),
            optimizedMdict: optimized,
            scriptPath: resolvedPath(in: directory, files: metadata.files, keys: ["script"], fileManager: fileManager)
        )
    }

    private func makeRealmDictionary(
        name: String,
        dictionaryID: String,
        pair: LanguageToLanguage,
        metadata: LocalDictionaryMetadata,
        directory: URL,
        fileManager: FileManager
    ) -> MongoDict? {
        guard let realmPath = resolvedPath(in: directory, files: metadata.files, keys: ["realm"], fileManager: fileManager) else {
            return nil
        }

        return MongoDict(
            name: name,
            dictionaryType: pair.asDescriptor(
                id: dictionaryID,
                displayName: name,
                backend: .realm,
                parser: .scriptJS
            ),
            databasePath: realmPath,
            scriptPath: resolvedPath(in: directory, files: metadata.files, keys: ["script"], fileManager: fileManager)
        )
    }

    private func makeKanjiSqliteDictionary(
        name: String,
        dictionaryID: String,
        pair: LanguageToLanguage,
        metadata: LocalDictionaryMetadata,
        directory: URL,
        fileManager: FileManager
    ) -> KanjiDictSQLiteDictionary? {
        guard let dbPath = resolvedPath(in: directory, files: metadata.files, keys: ["db", "sqlite"], fileManager: fileManager) else {
            return nil
        }

        return KanjiDictSQLiteDictionary(
            name: name,
            dictionaryType: pair.asDescriptor(
                id: dictionaryID,
                displayName: name,
                backend: .unknown,
                parser: .structured,
                includeInCrossDictionaryLookup: false
            ),
            databasePath: dbPath
        )
    }

    private func dictionaryIdentifier(documentsDirectory: URL, dictionaryDirectory: URL, metadataID: String) -> String {
        let basePath = documentsDirectory.path
        let currentPath = dictionaryDirectory.path

        guard currentPath.hasPrefix(basePath) else {
            return metadataID
        }

        let relativePath = String(currentPath.dropFirst(basePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relativePath.isEmpty else {
            return metadataID
        }

        let components = relativePath.split(separator: "/", omittingEmptySubsequences: true)
        guard let root = components.first, !root.isEmpty else {
            return metadataID
        }

        return String(root)
    }

    private func uniqueDictionaryName(for baseName: String, usedNames: inout Set<String>) -> String {
        guard !usedNames.contains(baseName) else {
            var index = 2
            while usedNames.contains("\(baseName)-\(index)") {
                index += 1
            }
            let unique = "\(baseName)-\(index)"
            usedNames.insert(unique)
            return unique
        }

        usedNames.insert(baseName)
        return baseName
    }

    private func resolvedPath(in directory: URL, files: [String: String], keys: [String], fileManager: FileManager) -> String? {
        for key in keys {
            if let relative = files[key], !relative.isEmpty {
                let path = directory.appendingPathComponent(relative).path
                if fileManager.fileExists(atPath: path) {
                    return path
                }
            }
        }
        return nil
    }

    private func languagePair(searchCode: String, resultsCode: String) -> LanguageToLanguage {
        LanguageToLanguage(
            searchLanguage: language(fromCode: searchCode),
            resultsLanguage: language(fromCode: resultsCode)
        )
    }

    private func language(fromCode code: String) -> Language {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return Language(rawValue: normalized)
    }

    private func applySavedDictionarySearchOrder(to dictionaries: [any DictionaryProtocol]) -> [any DictionaryProtocol] {
        let savedOrder = UserDefaults.standard.stringArray(forKey: "dictionarySearchOrder") ?? []
        guard !savedOrder.isEmpty else {
            return dictionaries
        }

        let savedIndex = Dictionary(uniqueKeysWithValues: savedOrder.enumerated().map { ($1, $0) })
        return dictionaries
            .enumerated()
            .sorted { lhs, rhs in
                let lhsRank = savedIndex[lhs.element.dictionaryType.id]
                    ?? savedIndex[lhs.element.name]
                    ?? Int.max
                let rhsRank = savedIndex[rhs.element.dictionaryType.id]
                    ?? savedIndex[rhs.element.name]
                    ?? Int.max

                if lhsRank == rhsRank {
                    return lhs.offset < rhs.offset
                }
                return lhsRank < rhsRank
            }
            .map(\.element)
    }
}

private let defaultDictionaryRegistry: any DictionaryRegistry = DefaultDictionaryRegistry()

func createAvailableDictionaries() -> [any DictionaryProtocol] {
    return defaultDictionaryRegistry.createAvailableDictionaries()
}
