//
//  WordType.swift
//  CJE Dictionary
//

import Foundation

struct Word: Hashable, Codable {
    let id: String
    let dictionaryName: String
    let word: String
    let readings: [String]

    init(id: String, dictionaryName: String, word: String, readings: [String]) {
        self.id = id
        self.dictionaryName = dictionaryName
        self.word = word
        self.readings = readings
    }
}
