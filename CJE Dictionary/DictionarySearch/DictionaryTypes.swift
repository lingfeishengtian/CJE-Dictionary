//
//  DictionaryTypes.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 8/3/24.
//

import Foundation
import RealmSwift
import SQLite
import IPADic
import Mecab_Swift
import OrderedCollections

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

struct LanguageToLanguage: Hashable {
    let searchLanguage: Language
    let resultsLanguage: Language
}

enum Language: String, CaseIterable, Hashable, Identifiable, Codable {
    var id: Language {
        self
    }
    
    var ordered: Int {
        switch (self) {
        case .EN: 1
        case .CN: 2
        case .JP: 3
        }
    }
    
    case CN = "cn"
    case JP = "ja"
    case EN = "en"
}

let LOCAL_REALM_URL = exportFolderOf(dictionary: "jp-cn").appending(component: "jp-cn.realm", directoryHint: .notDirectory)

let CONFIGURATION = {
    var configuration = Realm.Configuration.defaultConfiguration
    configuration.fileURL = LOCAL_REALM_URL
    configuration.schemaVersion = 5
    return configuration
}()

enum YomikataForms : String {
    case Onyomi = "ja_on"
    case Kunyomi = "ja_kun"
    case Nanori = "nanori"
    case Pinyin = "pinyin"
}

// TODO: KANJI stuff (show simplified chinese character)
// TODO: search with chinese simplified characters (auto convert to japanese)
