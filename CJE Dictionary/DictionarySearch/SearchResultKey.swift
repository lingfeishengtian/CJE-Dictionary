//
//  SearchResultKey.swift
//  CJE Dictionary
//
//  Created by [Your Name] on [Date].
//

import Foundation
import mdict_tools

/// Key structure for search results that holds minimal information needed to retrieve full word details later
struct SearchResultKey: Hashable, Codable {
    /// Unique identifier for this key in the dictionary
    let id: String
    
    /// Name of the dictionary this result came from
    let dictionaryName: String
    
    /// Key text (from MdictOptimized)
    let keyText: String
    
    /// Key ID from MdictOptimized
    let keyId: Int64
    
    /// Optional readings array (if available)
    let readings: [String]?
    
    init(id: String, dictionaryName: String, keyText: String, keyId: Int64, readings: [String]? = nil) {
        self.id = id
        self.dictionaryName = dictionaryName
        self.keyText = keyText
        self.keyId = keyId
        self.readings = readings
    }
    
    /// Initialize from a KeyBlock (from MdictOptimized)
    init(fromKeyBlock keyBlock: KeyBlock, dictionaryName: String, readings: [String]? = nil) {
        self.id = keyBlock.keyText
        self.dictionaryName = dictionaryName
        self.keyText = keyBlock.keyText
        self.keyId = Int64(keyBlock.keyId)
        self.readings = readings
    }
}
