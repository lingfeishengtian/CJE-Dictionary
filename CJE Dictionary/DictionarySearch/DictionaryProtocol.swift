//
//  DictionaryProtocol.swift
//  CJE Dictionary
//
//  Created by [Your Name] on [Date].
//

import Foundation

/// Protocol defining the interface for all dictionary types
protocol DictionaryProtocol {
    /// The name of this dictionary type
    var name: String { get }
    
    /// Type information for this dictionary (search language and result language)
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
}

// MARK: - Default Implementations

extension DictionaryProtocol {
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
}
