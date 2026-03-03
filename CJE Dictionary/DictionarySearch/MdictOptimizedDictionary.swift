//
//  MdictOptimizedDictionary.swift
//  CJE Dictionary
//
//  Created by [Your Name] on [Date].
//

import Foundation
import mdict_tools

/// Dictionary implementation for MdictOptimized format
struct MdictOptimizedDictionary: DictionaryProtocol {
    let name: String
    let type: LanguageToLanguage
    private let optimizedMdict: MdictOptimized
    
    /// Initialize with an already created MdictOptimized instance
    /// - Parameters:
    ///   - name: Name of the dictionary
    ///   - type: Language mapping for this dictionary
    ///   - optimizedMdict: Pre-created MdictOptimized instance
    init(name: String, type: LanguageToLanguage, optimizedMdict: MdictOptimized) {
        self.name = name
        self.type = type
        self.optimizedMdict = optimizedMdict
    }

    private func keyToSearchResult(_ keyBlock: KeyBlock) -> SearchResultKey {
        SearchResultKey(
            fromKeyBlock: keyBlock,
            dictionaryName: name,
            readings: try! optimizedMdict.getReadings(keyBlock: keyBlock)
        )
    }
    
    // MARK: - DictionaryProtocol Implementation
    
    func searchExact(_ searchString: String) -> DictionaryStreamProtocol {
        do {
            // Perform prefix search for exact match
            let firstPage = try optimizedMdict.setSearchPrefixPaged(prefix: searchString, pageSize: 100)
            
            // Create SearchResultKey objects instead of full Word objects
            let results = firstPage.results
                .filter { $0.keyText == searchString }
                .map(keyToSearchResult)
            
            return DictionaryStream(keys: results)
        } catch {
            print("Error searching exact match for '\(searchString)': \(error)")
            return DictionaryStream(keys: [])
        }
    }
    
    func searchPrefix(_ prefix: String) -> DictionaryStreamProtocol {
        do {
            // Perform prefix search with larger page size to get more results
            let firstPage = try optimizedMdict.setSearchPrefixPaged(prefix: prefix, pageSize: 100)
            
            // Create SearchResultKey objects instead of full Word objects
            let results = firstPage.results.map(keyToSearchResult)
            
            return DictionaryStream(keys: results)
        } catch {
            print("Error searching prefix '\(prefix)': \(error)")
            return DictionaryStream(keys: [])
        }
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
    
    /// Get the actual word content from a search result key
    /// - Parameter key: The SearchResultKey to resolve
    /// - Returns: Word object or nil if not found
    func getWord(fromKey key: SearchResultKey) -> Word? {
        guard let keyId = UInt64(exactly: key.keyId) else {
            return nil
        }

        do {
            let keyBlock = KeyBlock(keyId: keyId, keyText: key.keyText)
            _ = try optimizedMdict.recordAt(keyBlock: keyBlock)
            return Word(
                id: key.id,
                dict: .mdictOptimized,
                word: key.keyText,
                readings: key.readings ?? []
            )
        } catch {
            print("Error getting word from key '\(key.keyText)': \(error)")
            return nil
        }
    }
    
    func searchPrefixPaged(_ prefix: String, pageSize: Int, cursor: String?) -> (DictionaryStreamProtocol, String?) {
        do {
            let page: PrefixSearchPage
            
            if let cursorString = cursor {
                // Continue from previous cursor
                let cursorObj = PrefixSearchCursor(afterKey: cursorString)
                page = try optimizedMdict.prefixSearchNextPage(cursor: cursorObj)
            } else {
                // Start new search
                page = try optimizedMdict.setSearchPrefixPaged(prefix: prefix, pageSize: UInt64(pageSize))
            }
            
            // Create SearchResultKey objects instead of full Word objects
            let results = page.results.map(keyToSearchResult)
            
            let nextCursor = page.nextCursor?.afterKey
            
            return (DictionaryStream(keys: results), nextCursor)
        } catch {
            print("Error searching prefix paged '\(prefix)': \(error)")
            return (DictionaryStream(keys: []), nil)
        }
    }
    
    func wordCount() -> Int {
        // MdictOptimized doesn't expose a direct word count
        return 0
    }
    
    func containsWord(_ word: String) -> Bool {
        // Check if the word exists by performing an exact search
        var results = searchExact(word)
        return results.next() != nil
    }
}
