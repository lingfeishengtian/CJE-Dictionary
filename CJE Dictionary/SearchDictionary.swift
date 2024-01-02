//
//  SearchDictionary.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/31/23.
//

import Foundation
import RealmSwift
import SwiftSoup
import SQLite

class Wort: Object {
    @Persisted(primaryKey: true) var objectId: String?
    @Persisted var spell: String?
    @Persisted var pron: String?
    @Persisted var excerpt: String?
    @Persisted var accent: String?
    @Persisted var romaji: String?
    @Persisted var createdBy: String?
    @Persisted var updatedBy: String?
    @Persisted var createdAt: Date?
    @Persisted var updatedAt: Date?
    @Persisted var isDirty: Bool?
    @Persisted var tags: String?
    @Persisted var langEnv: String?
    @Persisted var isTrash: Bool?
    @Persisted var libId: String?
    @Persisted var isFree: Bool?
}

class Subdetails: Object {
    @Persisted(primaryKey: true) var objectId: String?
    @Persisted var title: String?
    @Persisted var index: Int?
    @Persisted var wordId: String?
    @Persisted var detailsId: String?
    @Persisted var isTrash: Bool?
}

class Example: Object {
    @Persisted(primaryKey: true) var objectId: String?
    @Persisted var title: String?
    @Persisted var trans: String?
    @Persisted var index: Int?
    @Persisted var wordId: String?
    @Persisted var subdetailsId: String?
    @Persisted var isTrash: Bool?
}

class Details: Object {
    @Persisted(primaryKey: true) var objectId: String?
    @Persisted var title: String?
    @Persisted var index: Int?
    @Persisted var wordId: String?
    @Persisted var isTrash: Bool?
}

class WordBank: Object {
    @Persisted var word: String
    @Persisted var dict: String?
}

let LOCAL_REALM_URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(component: "dict.realm", directoryHint: .notDirectory)
let BUNDLE_CN_JP_DICT = Bundle.main.url(forResource: "jp-cn", withExtension: "realm")
enum DICTIONARY_NAMES: String, CaseIterable {
    case jitendex = "jitendexDB"
    case shogakukanjcv3 = "Shogakukanjcv3DB"
}

let CONFIGURATION = {
    var configuration = Realm.Configuration.defaultConfiguration
    configuration.fileURL = LOCAL_REALM_URL
    configuration.schemaVersion = 5
    return configuration
}()

let DatabaseConnections: [DICTIONARY_NAMES:Connection] = {
    var ret: [DICTIONARY_NAMES:Connection] = [:]
    for dictName in DICTIONARY_NAMES.allCases {
        do {
            ret[dictName] = try Connection(exportFolderOf(dictionary: dictName).appending(path: dictName.rawValue.dropLast("DB".count), directoryHint: .notDirectory).appendingPathExtension("db").path())
        } catch {
            print("Unable to connect to \(dictName)")
        }
    }
    return ret
}()

@inline(__always) func exportFolderOf(dictionary dictName: DICTIONARY_NAMES) -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(component: dictName.rawValue, directoryHint: .isDirectory)
}

let realm = try! Realm(configuration: CONFIGURATION)

func createDictionaryIfNotPresent() {
    if let existingRealm = BUNDLE_CN_JP_DICT {
        do {
            if (!FileManager.default.fileExists(atPath: LOCAL_REALM_URL.path())) {
                try FileManager.default.copyItem(at: existingRealm, to: LOCAL_REALM_URL)
            }
        } catch {
            print("Error occured while copying: \(error)")
        }
    }
    
    for dictName in DICTIONARY_NAMES.allCases {
        let exportFolder = exportFolderOf(dictionary: dictName)
        if FileManager.default.fileExists(atPath: exportFolder.path()) {
            print("\(dictName) already exists")
            continue
        }
        do {
            try unzipDatabase(urlOfZip: Bundle.main.url(forResource: dictName.rawValue, withExtension: "zip")!, exportFolder: exportFolder)
        } catch {
            print("Error occurred while adding dictionary entries")
            // TODO: Show error to user indicating that they have a corrupted binary
        }
    }
}

//func onEntryReceieved(wordID: String, html: String, type: DictEntryType) {
//    do {
//        let doc = try SwiftSoup.parse(html)
//        
//        if (type == .Definition) {
//            let pronounciationElements = try attemptTwoSelectors(doc: doc, selectorA: ".pronunciation-text", selectorB: ".pinyin_h")
//            var pronounciationText = try pronounciationElements.text(trimAndNormaliseWhitespace: true)
//            let definitionsAndReibun = try attemptTwoSelectors(doc: doc, selectorA: ".sense", selectorB: "[data-orgtag]")
//            let termElems = try attemptTwoSelectors(doc: doc, selectorA: ".headline ruby, .headline .kanji-form-furigana", selectorB: "[data-orgtag=\"subheadword\"]")
//            var term = ""
//            
//            let shouldAddPronounciation = pronounciationText.isEmpty
//            for res in termElems {
//                if (res.hasAttr("data-orgtag")) {
//                    term += try res.text()
//                } else {
//                    term += res.textNodes().first?.text() ?? ""
//                    if (shouldAddPronounciation) {
//                        pronounciationText += try res.select("rt").text()
//                    }
//                }
//            }
//            
//            print("term: \(term) Pronounciation: \(pronounciationText)")
//            for elem in definitionsAndReibun {
//                let glossary = try elem.select(".glossary")
//                let reibun = try elem.select(".example-container")
//                
//                // TODO: 参见
//                if (glossary.isEmpty() && reibun.isEmpty()) {
//                    // TODO: glossary and reibun pass as html
//                    if (try elem.attr("data-orgtag") == "meaning") {
//                        //print("Definition: \(try elem.text())")
//                    } else {
//                        //print("Reibun: \(try elem.text())")
//                    }
//                    for canJian in try doc.select("a") {
//                        //print("参见: \(try canJian.text())")
//                    }
//                } else {
//                    // TODO: glossary and reibun pass as html
//                    //print ("Definition: \(try glossary.text()) and Reibun: \(try reibun.text())")
//                }
//            }
//        }
//        
//    } catch {
//        print("\(error) occurred, skipping \(wordID)")
//    }
//}

func attemptTwoSelectors(doc: SwiftSoup.Document, selectorA: String, selectorB: String) throws -> Elements {
    let optionA = try doc.select(selectorA)
    let optionB = try doc.select(selectorB)
    
    if (optionA.isEmpty()) {
        return optionB
    }
    return optionA
}

func sortResults(a: Wort, b: Wort, searchString: String) -> Bool {
    let aS = a.spell!
    let bS = b.spell!
    let aSStarts = aS.starts(with: searchString)
    let bSStarts = bS.starts(with: searchString)
    if ((aSStarts && bSStarts) || (!aSStarts && !bSStarts)) {
        if (aS.count == bS.count) {
            return aS.localizedStandardCompare(bS) == .orderedAscending
        } else {
            return aS.count < bS.count
        }
    } else {
        return aSStarts
    }
}

func searchText(searchString: String) -> [Wort] {
    // TODO: Deconjugate and smart search
    var res: [Wort] = []
    for db in DICTIONARY_NAMES.allCases {
        let seq = searchDatabase(databaseName: db, for: searchString)
        for row in seq {
            var splitRowTerms = try! row.get(Expression<String>("w")).split(separator: "|")
            for p in 0..<splitRowTerms.count{
                if splitRowTerms[p].hasPrefix("┏") {
                    splitRowTerms[p].removeFirst()
                }
                if (splitRowTerms[p].starts(with: "@jmdict") ||
                    (splitRowTerms[p].contains("【") && splitRowTerms[p].contains( "】"))) {
                    continue
                }
                let searchRealmForVal = res.first(where: {$0.spell ?? "" == (splitRowTerms[p])}) == nil
                if (searchRealmForVal) {
                    let newWort = Wort()
                    newWort.spell = String(splitRowTerms[p])
                    newWort.pron = (splitRowTerms.count > 1 && p != splitRowTerms.count - 1) ? String(splitRowTerms.last!) : nil
                    res.append(newWort)
                }
                if (res.count > 100) {
                    return (res.sorted(by: { sortResults(a: $0, b: $1, searchString: searchString) }))
                }
            }
        }
    }
    return (res.sorted(by: { sortResults(a: $0, b: $1, searchString: searchString) }))
}

func searchDatabase(databaseName dictName: DICTIONARY_NAMES, for searchStr: String) -> AnySequence<Row> {
    do {
        let db = DatabaseConnections[dictName]!
        let word = Table("word")
        let w = Expression<String>("w")
        let results = word.filter(w.like("%\(searchStr)%"))
        return try db.prepare(results)
    } catch {
        return AnySequence([])
    }
}
