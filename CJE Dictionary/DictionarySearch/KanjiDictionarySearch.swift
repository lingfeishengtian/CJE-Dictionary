//
//  KanjiDictionarySearch.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 8/4/24.
//

import Foundation
import SQLite

let KanjiDB: Connection? = {
    do {
        let newPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(component: "kanjidict2.db", directoryHint: .notDirectory)
        return try Connection(newPath.path())
    } catch {
        print("Can't connect to Kanjidict \(error)")
        return nil
    }
}()

enum KanjiError: Error {
    case runtimeError(String)
}

func getKanjiInfo(for strings: [String]) -> [KanjiInfo] {
    var kanjiSet = Set([Character]())
    for string in strings {
        let hanRanges = string.ranges(of: /\p{Han}/)
        for r in hanRanges {
            kanjiSet.formUnion(string[r])
        }
    }
    var searchedKanjis: [KanjiInfo] = []
    for kanji in kanjiSet {
        do {
            searchedKanjis.append(try KanjiInfo(for: kanji))
        } catch {
            print("Could not get kanji \(kanji) cause \(error)")
        }
    }
    return searchedKanjis
}

class KanjiInfo : Identifiable {
    let kanjiCharacter: Character
    let jlpt: Int?
    let grade: Int?
    let frequency: Int?
    let readings: [String:[String]]
    let strokeCount: [Int]
    let meaning: [String]
    
    let id: Character
    
    var description : String {
        return "\(kanjiCharacter): JLPT \(String(describing: jlpt)) Grade \(grade ?? -1) Freq \(String(describing: frequency)) StrokeCount\(strokeCount)\nReadings \(readings)\nMeanings \(meaning)"
    }
    
    init(kanjiCharacter: Character, jlpt: Int?, grade: Int?, frequency: Int?, readings: [String : [String]], strokeCount: [Int], meaning: [String]) {
        self.kanjiCharacter = kanjiCharacter
        self.jlpt = jlpt
        self.grade = grade
        self.frequency = frequency
        self.readings = readings
        self.strokeCount = strokeCount
        self.meaning = meaning
        
        self.id = kanjiCharacter
    }
    
    init(for kanji: Character) throws {
        let rowIt = try KanjiDB?.prepareRowIterator("SELECT * FROM character WHERE literal == ?", bindings: String(kanji))
        if let a = rowIt?.next() {
            kanjiCharacter = kanji
            jlpt = try a.get(Expression<Int?>("jlpt"))
            grade = try a.get(Expression<Int?>("grade"))
            frequency = try a.get(Expression<Int?>("freq"))
            
            let id = try a.get(Expression<Int>("id"))
            
            let meanings = try KanjiDB?.prepareRowIterator("SELECT * FROM meaning WHERE fk == ?", bindings: id)
            var meaningStrings = [String]()
            while let m = meanings?.next() {
                meaningStrings.append(try m.get(Expression<String>("value")))
            }
            self.meaning = meaningStrings
            
            let readingQuery = try KanjiDB?.prepareRowIterator("SELECT * FROM reading WHERE fk == ?", bindings: id)
            var readings = [String:[String]]()
            while let r = readingQuery?.next() {
                let t = try r.get(Expression<String>("type"))
                let v = try r.get(Expression<String>("value"))
                if readings[t] == nil {
                    readings[t] = [v]
                } else {
                    readings[t]?.append(v)
                }
            }
            
            let nanoris = try KanjiDB?.prepareRowIterator("SELECT * FROM nanori WHERE fk == ?", bindings: id)
            readings[YomikataForms.Nanori.rawValue] = []
            while let m = nanoris?.next() {
                readings[YomikataForms.Nanori.rawValue]?.append(try m.get(Expression<String>("value")))
            }
            self.readings = readings
            
            let stroke_counts = try KanjiDB?.prepareRowIterator("SELECT * FROM stroke_count WHERE fk == ?", bindings: id)
            var strokeCounts = [Int]()
            while let stroke_count = stroke_counts?.next() {
                strokeCounts.append(try stroke_count.get(Expression<Int>("count")))
            }
            self.strokeCount = strokeCounts
        } else {
            throw KanjiError.runtimeError("Kanji character not found")
        }
        
        self.id = kanjiCharacter
    }
}

var hanziKanji: [Character: [Character]] = {
    guard let path = Bundle.main.path(forResource: "HanziToKanji", ofType: "txt") else {
        return [:]
    }
    do {
        let text = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
        let lines = text.components(separatedBy: CharacterSet.newlines)
        
        var hanziKanji: [Character: [Character]] = [:]
        
        for line in lines {
            if line.split(separator: " ").count < 2 {
                continue
            }
            guard let hanzi = line.split(separator: " ")[0].first, let kanji = line.split(separator: " ")[1].first else {
                continue
            }
            if hanziKanji[hanzi] != nil {
                hanziKanji[hanzi]?.append(kanji)
            } else {
                hanziKanji[hanzi] = [kanji]
            }
        }
        
        return hanziKanji
    } catch {
        print("Error occurred when initializing Hanzi to Kanji conversion")
        return [:]
    }
}()

func convertKanjiToHanzi(character: Character) -> Character? {
    return hanziKanji.first(where: { hanzi, kanjis in
        return kanjis.contains(character)
    })?.key
}

func convertHanziToKanji(character: Character) -> [Character] {
    return hanziKanji[character] ?? []
}

// This will only choose the first character option (usually shinjitai vs kyuujitai, but can also be something like 个 vs 個 vs 箇)
func convertHanziStringToKanji(str: String) -> String {
    var modifyStr = str
    let hanRanges = modifyStr.ranges(of: /\p{Han}/)
    for r in hanRanges {
        var newSection = ""
        for kChar in modifyStr[r] {
            let converted = convertHanziToKanji(character: kChar)
            if converted.count > 0 {
                newSection.append(converted[0])
            } else {
                newSection.append(kChar)
            }
        }
        
        modifyStr.replaceSubrange(r, with: newSection)
    }
    
    return modifyStr
}

