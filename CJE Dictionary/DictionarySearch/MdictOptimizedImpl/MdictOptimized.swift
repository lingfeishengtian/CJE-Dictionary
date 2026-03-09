//
//  MdictOptimized.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/5/26.
//

import Foundation
import mdict_tools

enum MdictDefinitionParseError: LocalizedError {
    case missingRecordData
    case decodingFailed
    case missingScript(String)
    case invalidScriptResult

    var errorDescription: String? {
        switch self {
        case .missingRecordData:
            return "No definition record data was found for this key."
        case .decodingFailed:
            return "Unable to decode definition content from record data."
        case .missingScript(let path):
            return "Script.js not found at path: \(path)"
        case .invalidScriptResult:
            return "Script.js returned an invalid result payload."
        }
    }
}


/// Dictionary implementation for MdictOptimized format.
struct MdictOptimizedDictionary: DictionaryProtocol {
    let name: String
    let dictionaryType: DictionaryTypeDescriptor
    private let optimizedMdict: MdictOptimized
    private let scriptPath: String?

    init(name: String, type: LanguageToLanguage, optimizedMdict: MdictOptimized, scriptPath: String? = nil) {
        self.name = name
        self.dictionaryType = type.asDescriptor(
            id: name,
            displayName: name,
            backend: .mdictOptimized,
            parser: .scriptJS
        )
        self.optimizedMdict = optimizedMdict
        self.scriptPath = scriptPath
    }

    init(name: String, dictionaryType: DictionaryTypeDescriptor, optimizedMdict: MdictOptimized, scriptPath: String? = nil) {
        self.name = name
        self.dictionaryType = dictionaryType
        self.optimizedMdict = optimizedMdict
        self.scriptPath = scriptPath
    }

    /// Convenience initializer that resolves assets by file names and creates MdictOptimized.
    /// - Parameters:
    ///   - name: Name of dictionary
    ///   - type: Search/result language mapping
    ///   - fstFileName: FST file name, e.g. "jitendex.fst"
    ///   - readingsFileName: Readings file name, e.g. "jitendex.rd"
    ///   - recordFileName: Record file name, e.g. "jitendex.def"
    ///   - scriptFileName: Script file name, e.g. "Script.js"
    ///   - bundle: Bundle to search first (defaults to main bundle)
    init?(
        name: String,
        type: LanguageToLanguage,
        fstFileName: String,
        readingsFileName: String,
        recordFileName: String,
        scriptFileName: String = "Script.js",
        bundle: Bundle = .main
    ) {
        guard let fstPath = Self.resolvePath(fileName: fstFileName, bundle: bundle),
              let readingsPath = Self.resolvePath(fileName: readingsFileName, bundle: bundle),
              let recordPath = Self.resolvePath(fileName: recordFileName, bundle: bundle),
              let scriptPath = Self.resolvePath(fileName: scriptFileName, bundle: bundle)
                ?? Self.resolvePath(fileName: scriptFileName, inDirectory: name, bundle: bundle),
              let optimized = MdictOptimizedManager.createOptimized(
                fromBundle: "",
                fstPath: fstPath,
                readingsPath: readingsPath,
                recordPath: recordPath
              )
        else {
            return nil
        }

        self.name = name
        self.dictionaryType = type.asDescriptor(
            id: name,
            displayName: name,
            backend: .mdictOptimized,
            parser: .scriptJS
        )
        self.optimizedMdict = optimized
        self.scriptPath = scriptPath
    }

    private static func resolvePath(fileName: String, bundle: Bundle) -> String? {
        let fileURL = URL(fileURLWithPath: fileName)
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension.isEmpty ? nil : fileURL.pathExtension

        if let path = bundle.path(forResource: baseName, ofType: fileExtension) {
            return path
        }

        if let src = ProcessInfo.processInfo.environment["SRCROOT"] {
            let candidate = URL(fileURLWithPath: src)
                .appendingPathComponent("Resources")
                .appendingPathComponent(fileName)
                .path
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    private static func resolvePath(fileName: String, inDirectory directory: String, bundle: Bundle) -> String? {
        let fileURL = URL(fileURLWithPath: fileName)
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension.isEmpty ? nil : fileURL.pathExtension

        if let path = bundle.path(forResource: baseName, ofType: fileExtension, inDirectory: directory) {
            return path
        }

        return nil
    }

    private func keyToSearchResult(_ keyBlock: KeyBlock) -> SearchResultKey {
        SearchResultKey(
            fromKeyBlock: keyBlock,
            dictionaryName: name,
            readings: try? optimizedMdict.getReadings(keyBlock: keyBlock)
        )
    }

    func searchExact(_ searchString: String) -> DictionaryStreamProtocol {
        return MdictEnumeratedStream(
            optimizedMdict: optimizedMdict,
            dictionaryName: name,
            prefix: searchString,
            pageSize: 100,
            exactMatch: searchString,
            includeReadings: true
        )
    }

    func searchPrefix(_ prefix: String) -> DictionaryStreamProtocol {
        return MdictEnumeratedStream(
            optimizedMdict: optimizedMdict,
            dictionaryName: name,
            prefix: prefix,
            pageSize: 100,
            includeReadings: true
        )
    }

    func getWord(byId id: AnyHashable) -> Word? {
        let keyIdString: String
        if let stringId = id.base as? String {
            keyIdString = stringId
        } else if let int64Id = id.base as? Int64 {
            keyIdString = String(int64Id)
        } else if let intId = id.base as? Int {
            keyIdString = String(intId)
        } else if let uint64Id = id.base as? UInt64 {
            keyIdString = String(uint64Id)
        } else {
            keyIdString = String(describing: id.base)
        }

        if let keyId = Int64(keyIdString) {
            let key = SearchResultKey(
                id: keyIdString,
                dictionaryName: name,
                keyText: "",
                keyId: keyId
            )
            return getWord(fromKey: key)
        }

        return nil
    }

    func getWord(fromKey key: SearchResultKey) -> Word? {
        if getRecordData(fromKey: key) != nil {
            return Word(
                id: key.id,
                dictionaryName: name,
                word: key.keyText,
                readings: key.readings ?? []
            )
        }

        return nil
    }

    func getRecordData(fromKey key: SearchResultKey) -> Data? {
        guard let keyId = UInt64(exactly: key.keyId) else {
            return nil
        }

        do {
            let keyBlock = KeyBlock(keyId: keyId, keyText: key.keyText)
            return try optimizedMdict.recordAt(keyBlock: keyBlock)
        } catch {
            print("Error getting record data from key '\(key.keyText)': \(error)")
            return nil
        }
    }

    func getDefinitionGroups(fromKey key: SearchResultKey) async throws -> [DefinitionGroup] {
        guard let recordData = getRecordData(fromKey: key) else {
            throw MdictDefinitionParseError.missingRecordData
        }

        guard let html = String(data: recordData, encoding: .utf8)
            ?? String(data: recordData, encoding: .utf16)
            ?? String(data: recordData, encoding: .unicode),
            !html.isEmpty
        else {
            throw MdictDefinitionParseError.decodingFailed
        }

        guard let scriptPath else {
            throw MdictDefinitionParseError.missingScript("Bundle.main")
        }

        let script = try String(contentsOfFile: scriptPath, encoding: .utf8)
        return try await ScriptExecutor.execute(html: html, script: script)
    }

    func searchPrefixPaged(_ prefix: String, pageSize: Int, cursor: String?) -> (DictionaryStreamProtocol, String?) {
        do {
            let page: PrefixSearchPage

            if let cursorString = cursor {
                let cursorObj = PrefixSearchCursor(afterKey: cursorString)
                page = try optimizedMdict.prefixSearchNextPage(cursor: cursorObj)
            } else {
                page = try optimizedMdict.setSearchPrefixPaged(prefix: prefix, pageSize: UInt64(pageSize))
            }

            let results = page.results.map(keyToSearchResult)
            let nextCursor = page.nextCursor?.afterKey
            return (DictionaryStream(keys: results), nextCursor)
        } catch {
            print("Error searching prefix paged '\(prefix)': \(error)")
            return (DictionaryStream(keys: []), nil)
        }
    }

    func wordCount() -> Int {
        return 0
    }

    func containsWord(_ word: String) -> Bool {
        var results = searchExact(word)
        return results.next() != nil
    }
}

