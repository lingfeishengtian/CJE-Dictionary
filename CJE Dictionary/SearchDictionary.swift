//
//  SearchDictionary.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/31/23.
//

import Foundation
import RealmSwift
import SwiftSoup

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

class LinkedWords: Object {
    @Persisted var objectId: String
    @Persisted var linkedToId: String
}

let LOCAL_REALM_URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(component: "dict.realm", directoryHint: .notDirectory)
let BUNDLE_CN_JP_DICT = Bundle.main.url(forResource: "jp-cn", withExtension: "realm")
let DICTIONARY_NAMES = [
    "JitendexParsable",
    "Shogakukanjicv3Parsed"
]
let CONFIGURATION = {
    var configuration = Realm.Configuration.defaultConfiguration
    configuration.fileURL = LOCAL_REALM_URL
    configuration.schemaVersion = 5
    return configuration
}()

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
    
    for dictName in DICTIONARY_NAMES {
        do {
            try enumerateDictionaryEntries(urlOfZip: Bundle.main.url(forResource: dictName, withExtension: "zip")!, onEntryReceived: onEntryReceieved(term:html:type:))
        } catch {
            print("Error occurred while adding dictionary entries")
            // TODO: Show error to user indicating that they have a corrupted binary
        }
    }
}

func onEntryReceieved(term: String, html: String, type: DictEntryType) {
    do {
        let doc = try SwiftSoup.parse(html)
        
        if (type == .Definition) {
            let pronounciationText = try attemptTwoSelectors(doc: doc, selectorA: ".pronunciation-text", selectorB: ".pinyin_h")
            let definitionsAndReibun = try attemptTwoSelectors(doc: doc, selectorA: ".sense", selectorB: "[data-orgtag]")
            
            print("Term: \(term) Pronounciation: \(try pronounciationText.first()?.text() ?? "N/A")")
            for elem in definitionsAndReibun {
                let glossary = try elem.select(".glossary")
                let reibun = try elem.select(".example-container")
                
                // TODO: 参见
                if (glossary.isEmpty() && reibun.isEmpty()) {
                    if (try elem.attr("data-orgtag") == "meaning") {
                        print("Definition: \(try elem.text())")
                    } else {
                        print("Reibun: \(try elem.text())")
                    }
                    for canJian in try doc.select("a") {
                        print("参见: \(try canJian.text())")
                    }
                } else {
                    print ("Definition: \(try glossary.text()) and Reibun: \(try reibun.text())")
                }
            }
        }
        
    } catch {
        print("\(error) occurred, skipping \(term)")
    }
}

func attemptTwoSelectors(doc: SwiftSoup.Document, selectorA: String, selectorB: String) throws -> Elements {
    let optionA = try doc.select(selectorA)
    let optionB = try doc.select(selectorB)
    
    if (optionA.isEmpty()) {
        return optionB
    }
    return optionA
}

func searchText(searchString: String) -> Results<Wort> {
    // TODO: Deconjugate first
    let searches = realm.objects(Wort.self).where {
        $0.spell.contains(searchString) || $0.pron.contains(searchString)
    }
    
    return searches
}
