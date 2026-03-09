//
//  DictionaryProtocol.swift
//  CJE Dictionary
//
//  Created by [Your Name] on [Date].
//

import Foundation

enum DictionaryDefinitionError: LocalizedError {
    case unsupported
    case kanjiUnsupported

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "This dictionary does not support parsed definitions."
        case .kanjiUnsupported:
            return "This dictionary does not support kanji-specific parsing."
        }
    }
}

struct KanjiInfo: Identifiable, Hashable, Sendable {
    let kanjiCharacter: Character
    let jlpt: Int?
    let grade: Int?
    let frequency: Int?
    let readings: [String: [String]]
    let strokeCount: Int?
    let meaning: [String]

    var id: Character { kanjiCharacter }
}

protocol KanjiDictionaryProtocol: DictionaryProtocol {
    func getKanjiInfo(fromKey key: SearchResultKey) throws -> KanjiInfo?
}

/// Protocol defining the interface for all dictionary types
protocol DictionaryProtocol {
    /// The name of this dictionary type
    var name: String { get }

    /// Rich type information used to determine backend and parser behavior.
    var dictionaryType: DictionaryTypeDescriptor { get }
    
    /// Legacy language pair retained for compatibility.
    var type: LanguageToLanguage { get }
    
    /// Search for words with exact match
    /// - Parameter searchString: The string to search for
    /// - Returns: DictionaryStreamProtocol of SearchResultKey objects matching the search
    func searchExact(_ searchString: String) -> DictionaryStreamProtocol
    
    /// Search for words with prefix match
    /// - Parameter prefix: The prefix to search for
    /// - Returns: DictionaryStreamProtocol of SearchResultKey objects matching the prefix
    func searchPrefix(_ prefix: String) -> DictionaryStreamProtocol
    
    /// Get word definitions by ID
    /// - Parameter id: The word ID
    /// - Returns: Word object or nil if not found
    func getWord(byId id: AnyHashable) -> Word?
    
    /// Get the actual word content from a search result key
    /// - Parameter key: The SearchResultKey to resolve
    /// - Returns: Word object or nil if not found
    func getWord(fromKey key: SearchResultKey) -> Word?

    /// Get raw record data for a search result key when supported by the dictionary backend.
    /// - Parameter key: The SearchResultKey to resolve
    /// - Returns: Raw record bytes or nil if unavailable
    func getRecordData(fromKey key: SearchResultKey) -> Data?

    /// Parse and return definition groups by running dictionary Script.js on the record content.
    /// - Parameter key: The SearchResultKey to resolve
    /// - Returns: Parsed definition groups
    func getDefinitionGroups(fromKey key: SearchResultKey) async throws -> [DefinitionGroup]
}

// MARK: - Default Implementations

extension DictionaryProtocol {
    var type: LanguageToLanguage {
        dictionaryType.languagePair
    }

    /// Default implementation for prefix search using exact search (fallback)
    func searchPrefix(_ prefix: String) -> DictionaryStreamProtocol {
        return searchExact(prefix)
    }
    
    /// Default implementation for paginated search
    func searchPrefixPaged(_ prefix: String, pageSize: Int, cursor: String?) -> (DictionaryStreamProtocol, String?) {
        // Default implementation - return all results with no pagination
        let words = searchPrefix(prefix)
        return (words, nil)
    }
    
    /// Default implementation for word count (fallback) - returns 0 for streamed dictionaries
    func wordCount() -> Int {
        return 0
    }

    /// Default implementation for backends that do not expose record bytes directly
    func getRecordData(fromKey key: SearchResultKey) -> Data? {
        return nil
    }

    func getDefinitionGroups(fromKey key: SearchResultKey) async throws -> [DefinitionGroup] {
        throw DictionaryDefinitionError.unsupported
    }
}

extension KanjiDictionaryProtocol {
    func getKanjiInfo(fromKey key: SearchResultKey) throws -> KanjiInfo? {
        throw DictionaryDefinitionError.kanjiUnsupported
    }
}
