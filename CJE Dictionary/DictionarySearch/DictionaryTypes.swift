//
//  DictionaryTypes.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 8/3/24.
//

import Foundation
import RealmSwift
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

    var searchLocaleCode: String {
        searchLanguage.localeCode
    }

    var resultsLocaleCode: String {
        resultsLanguage.localeCode
    }

    func asDescriptor(
        id: String,
        displayName: String,
        backend: DictionaryBackendType,
        parser: DictionaryParserType,
        includeInCrossDictionaryLookup: Bool = true
    ) -> DictionaryTypeDescriptor {
        DictionaryTypeDescriptor(
            id: id,
            displayName: displayName,
            searchLanguage: searchLanguage,
            resultsLanguage: resultsLanguage,
            backend: backend,
            parser: parser,
            includeInCrossDictionaryLookup: includeInCrossDictionaryLookup
        )
    }
}

enum DictionaryBackendType: String, Codable, Hashable, Sendable {
    case mdictOptimized
    case realm
    case unknown
}

enum DictionaryParserType: String, Codable, Hashable, Sendable {
    case scriptJS
    case plainHTML
    case structured
}

struct DictionaryTypeDescriptor: Hashable, Codable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let searchLanguage: Language
    let resultsLanguage: Language
    let backend: DictionaryBackendType
    let parser: DictionaryParserType
    let includeInCrossDictionaryLookup: Bool

    init(
        id: String,
        displayName: String,
        searchLanguage: Language,
        resultsLanguage: Language,
        backend: DictionaryBackendType,
        parser: DictionaryParserType,
        includeInCrossDictionaryLookup: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.searchLanguage = searchLanguage
        self.resultsLanguage = resultsLanguage
        self.backend = backend
        self.parser = parser
        self.includeInCrossDictionaryLookup = includeInCrossDictionaryLookup
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case searchLanguage
        case resultsLanguage
        case backend
        case parser
        case includeInCrossDictionaryLookup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        searchLanguage = try container.decode(Language.self, forKey: .searchLanguage)
        resultsLanguage = try container.decode(Language.self, forKey: .resultsLanguage)
        backend = try container.decode(DictionaryBackendType.self, forKey: .backend)
        parser = try container.decode(DictionaryParserType.self, forKey: .parser)
        includeInCrossDictionaryLookup = try container.decodeIfPresent(Bool.self, forKey: .includeInCrossDictionaryLookup) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(searchLanguage, forKey: .searchLanguage)
        try container.encode(resultsLanguage, forKey: .resultsLanguage)
        try container.encode(backend, forKey: .backend)
        try container.encode(parser, forKey: .parser)
        try container.encode(includeInCrossDictionaryLookup, forKey: .includeInCrossDictionaryLookup)
    }

    var languagePair: LanguageToLanguage {
        LanguageToLanguage(searchLanguage: searchLanguage, resultsLanguage: resultsLanguage)
    }
}

struct Language: RawRepresentable, Hashable, Identifiable, Codable, Sendable {
    let rawValue: String

    var id: String {
        rawValue
    }

    var localeCode: String {
        rawValue
    }

    init(rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

private func exportFolderOf(dictionary: String) -> URL {
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dictionaryFolder = documentsDirectory.appendingPathComponent(dictionary, isDirectory: true)

    if !FileManager.default.fileExists(atPath: dictionaryFolder.path) {
        try? FileManager.default.createDirectory(at: dictionaryFolder, withIntermediateDirectories: true)
    }

    return dictionaryFolder
}

let LOCAL_REALM_URL = exportFolderOf(dictionary: "jp-cn").appending(component: "jp-cn.realm", directoryHint: .notDirectory)

let CONFIGURATION = {
    var configuration = Realm.Configuration.defaultConfiguration
    configuration.fileURL = LOCAL_REALM_URL
    configuration.schemaVersion = 5
    return configuration
}()

enum YomikataForms: String {
    case Onyomi = "ja_on"
    case Kunyomi = "ja_kun"
    case Nanori = "nanori"
    case Pinyin = "pinyin"
}
