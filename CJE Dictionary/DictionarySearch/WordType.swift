//
//  WordType.swift
//  CJE Dictionary
//
//  Created by [Your Name] on [Date].
//

import Foundation

/// Flexible word type that can handle different ID types across dictionary formats
struct Word: Hashable, Codable {
    /// Unique identifier for the word - can be String, Int, or other types depending on dictionary format
    let id: String
    
    /// The dictionary this word belongs to
    let dict: DICTIONARY_NAMES
    
    /// The main word text
    let word: String
    
    /// Readings for the word (can be empty)
    let readings: [String]
    
    init(id: String, dict: DICTIONARY_NAMES, word: String, readings: [String]) {
        self.id = id
        self.dict = dict
        self.word = word
        self.readings = readings
    }
}
