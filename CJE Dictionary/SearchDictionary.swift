//
//  SearchDictionary.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/31/23.
//

import Foundation
import RealmSwift
import SQLite
import IPADic
import Mecab_Swift

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

typealias LanguageToLanguage = (Language, Language)
enum Language: String, CaseIterable, Identifiable {
    var id: Language {
        self
    }
    
    case CN
    case JP
    case EN
}

let LOCAL_REALM_URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(component: "dict.realm", directoryHint: .notDirectory)
let BUNDLE_CN_JP_DICT = Bundle.main.url(forResource: "jp-cn", withExtension: "realm")
enum DICTIONARY_NAMES: String, CaseIterable {
    case jitendex = "jitendexDB"
    case shogakukanjcv3 = "Shogakukanjcv3DB"
    
    // from $0 to $1
    func type() -> LanguageToLanguage {
        switch self {
        case .jitendex:
            return (.JP, .EN)
        case .shogakukanjcv3:
            return (.JP, .CN)
        }
    }
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
    
    for dbConnection in DatabaseConnections.values {
        do {
            try dbConnection.execute("""
                CREATE VIRTUAL TABLE wordIndex
                USING FTS5(id, w);
            """)
            try dbConnection.execute("""
                WITH cte AS (
                    SELECT id, '' w, w || '|' s
                    FROM word
                    UNION ALL
                    SELECT id,
                           SUBSTR(s, 0, INSTR(s, '|') - 1),
                           SUBSTR(s, INSTR(s, '|') + 1)
                    FROM cte
                    WHERE s <> ''
                )
                INSERT INTO wordIndex (id, w)
                SELECT id, w
                FROM cte
                WHERE w <> '';
            """)
            try dbConnection.execute("""
                DELETE FROM wordIndex WHERE w LIKE "%【%】%"
            """)
            try dbConnection.execute("""
                ANALYZE
            """)
        } catch {
            print("failed?")
        }
    }
}

func sortResults(a: DatabaseWord, b: DatabaseWord, searchString: String) -> Bool {
    let aS = a.word
    let bS = b.word
    let aSStarts = searchString.contains(aS)
    let bSStarts = searchString.contains(bS)
    
    if (aS.count == bS.count) {
        if ((aSStarts && bSStarts) || (!aSStarts && !bSStarts)) {
            return aS.localizedStandardCompare(bS) == .orderedAscending
        } else {
            return aSStarts
        }
    } else {
        return aS.count > bS.count
    }
}

class DatabaseWord: Hashable {
    let id: Int
    let dict: DICTIONARY_NAMES
    let word: String
    let readings: [String]
    let meaning: String
    
    init(id: Int, dict: DICTIONARY_NAMES, word: String, readingsString: String, meaning: String) {
        self.id = id
        self.dict = dict
        self.word = word
        var readingsTmp: [String] = []
        for reading in readingsString.split(separator: "|") {
            var r = reading
            if r.hasPrefix("┏") {
                r.removeFirst()
            }
            if (r.contains("【") && r.contains( "】")) {
                continue
            }
            readingsTmp.append(String(r))
        }
        self.readings = readingsTmp
        self.meaning = meaning
    }
    
    static func == (lhs: DatabaseWord, rhs: DatabaseWord) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
        hasher.combine(dict)
        hasher.combine(id)
    }
}

struct CJE_Definition {
    // TODO: Change to something like Wort
    let word: DatabaseWord
    let definitions: [(LanguageToLanguage, [DefinitionGroup])]
}

func lookupWord(word: DatabaseWord) -> CJE_Definition {
    // TODO: Allow user to select dictionaries
    var finDefs: [(LanguageToLanguage, [DefinitionGroup])] = []
//    guard let wordDef = getDefinition(databasename: word.dict, for: word.id) else {
//        return CJE_Definition(word: word, definitions: [])
//    }
    for dict in DICTIONARY_NAMES.allCases {
        var priority = -1
        if dict.type().1 == .CN {
            var potential: (LanguageToLanguage, [DefinitionGroup]) = (dict.type(), [])
            for reading in word.readings {
                let existsInRealm = realm.objects(Wort.self).where {
                    $0.spell == reading.trimmingCharacters(in: ["-", "…"])
                }
                let rPrio = reading.containsChineseCharacters ? 2 : 1
                if !existsInRealm.isEmpty && priority <= rPrio {
                    
                    priority = rPrio
                    let realmWort = existsInRealm.first!
                    
                    var tags: [Tag] = []
                    
                    for detail in realm.objects(Details.self).where({
                        $0.wordId == realmWort.objectId
                    }) {
                        if !(detail.title?.isEmpty ?? true) {
                            tags.append(Tag(shortName: detail.title ?? "", longName: detail.title ?? ""))
                        }
                    }
                    
                    let definitions: [Definition] = realm.objects(Subdetails.self).where {
                        $0.wordId == realmWort.objectId
                    }.map({ subdetail in
                        var exampleSentences: [ExampleSentence] = []
                        
                        for example in realm.objects(Example.self).where({
                            $0.subdetailsId == subdetail.objectId
                        }) {
                            exampleSentences.append(ExampleSentence(language: .JP, attributedString: AttributedString(example.title ?? "")))
                            exampleSentences.append(ExampleSentence(language: .CN, attributedString: AttributedString(example.trans ?? "")))
                        }
                        
                        return Definition(definition: subdetail.title ?? "", exampleSentences: exampleSentences)
                    })
                    potential = (dict.type(), [DefinitionGroup(tags: tags, definitions: definitions)])
                }
            }
            
            if priority >= 1 {
                finDefs.append(potential)
                continue
            }
        }
        if dict == word.dict {
            finDefs.append((dict.type(), word.parseDefinitionHTML()))
            continue
        }
        var passed: [String] = []
        var wordList = word.readings
        do {
            let res = __lookupWordHelper(wordList: &wordList, passedWords: &passed, dict: dict, strict: true)
            if let firstRow = res.0.first(where: {_ in true}) {
                finDefs.append((dict.type(), word.parseDefinitionHTML(otherHTML: try firstRow.get(Expression<String>("m")))))
            }
        } catch {
            print("\(error) when adding \(word.word) in \(dict)")
        }
    }
    return CJE_Definition(word: word, definitions: finDefs)
}

fileprivate func __lookupWordHelper(wordList: inout [String], passedWords: inout [String], dict: DICTIONARY_NAMES, strict: Bool) -> (AnySequence<Row>, Int) {
    if (wordList.isEmpty) {
        return (AnySequence([]), 0)
    }
    let word = wordList.popLast()!
    passedWords.append(word)
    let res = findSimilarWord(databaseName: dict, for: passedWords)
    if res.1 > 0 {
        if res.1 == 1 {
            return res
        } else {
            let deeperRun = __lookupWordHelper(wordList: &wordList, passedWords: &passedWords, dict: dict, strict: strict)
            if deeperRun.1 < 1 {
                return res
            }
            return deeperRun
        }
    } else {
        passedWords.removeLast()
        return __lookupWordHelper(wordList: &wordList, passedWords: &passedWords, dict: dict, strict: strict)
    }
}

class SearchResultsEnumerator: ObservableObject {
    var sQueryIterators: [(DICTIONARY_NAMES, RowIterator)] = []
    let pollingLimit: Int
    @Published var lazyArray: [DatabaseWord]
    let id: UUID = UUID()
    
    // TODO: multi squery support
    init(pollingLimit:Int = 30) {
        self.pollingLimit = pollingLimit
        lazyArray = []
    }
    
    func initSQueryForDict(dict: DICTIONARY_NAMES, sQuery: RowIterator) {
        sQueryIterators.append((dict, sQuery))
        print("initializing dict: \(dict.rawValue) at \(Date.now.timeIntervalSince1970)")
        addToLazyArray()
    }
    
    // Returns lazy array
    func addToLazyArray() {
        // TODO: Support in the future reading both at the same time
        for _ in 1...pollingLimit {
            print("Start adding word: \(Date.now.timeIntervalSince1970)")
            do {
                if sQueryIterators.isEmpty {
                    return
                }
                
                guard let row = try sQueryIterators.first?.1.failableNext() else {
                    sQueryIterators.removeFirst()
                    continue
                }
                
                let wordIndex = Table("wordIndex")
                let word = Table("word")
                let newWord = DatabaseWord(id: try! row.get(word[Expression<Int>("id")]),
                                           dict: sQueryIterators.first!.0,
                                           word: try! row.get(wordIndex[Expression<String>("w")]),
                                           readingsString: try! row.get(word[Expression<String>("w")]),
                                           meaning: try! row.get(Expression<String>("m")))
                print("End adding word (\(newWord.word)): \(Date.now.timeIntervalSince1970)")
                lazyArray.append(newWord)
                objectWillChange.send()
            } catch {
                print("error occurred for iterator, removing it \(error)")
                sQueryIterators.removeFirst()
            }
        }
        print("Exiting adding to lazy array \(Date.now.timeIntervalSince1970)")
    }
}

var sQuery: AnySequence<Row>? = nil
var it: AnySequence<Row>.Iterator? = nil

func searchText(searchString: String) -> SearchResultsEnumerator {
    // TODO: Deconjugate and smart search
    let ret = SearchResultsEnumerator()
    for dict in DICTIONARY_NAMES.allCases {
        let f = searchDatabase(databaseName: dict, for: searchString)
        if let it = f {
            ret.initSQueryForDict(dict: dict, sQuery: it)
        }
    }
    return ret
}

var partialSearchGlobalCache: [String: Set<DatabaseWord>] = [:]
let ipadic=IPADic()

func partialSearch(searchString: String) -> [DatabaseWord] {
    do {
        let tokenizer = try Tokenizer(dictionary: ipadic)
        let tokenized = tokenizer.tokenize(text: searchString)
            .filter({ $0.partOfSpeech != .particle ||
                $0.partOfSpeech != .prefix })
        var adjustedTokenized: [String] = []
        var resultSet: Set<DatabaseWord> = []
        var particlesUnused: [String] = []
        for (index, token) in tokenized.enumerated() {
            if adjustedTokenized.count >= 1 {
                if token.partOfSpeech == .noun {
                    if tokenized[index - 1].partOfSpeech == .noun {
                        if exactSearchDatabase(for: adjustedTokenized.last! + token.base).count >= 1 {
                            adjustedTokenized.append(adjustedTokenized.popLast()! + token.base)
                        } else {
                            adjustedTokenized.append(token.base)
                        }
                    } else {
                        adjustedTokenized.append(token.base)
                    }
                } else if token.partOfSpeech != .unknown && token.partOfSpeech != .particle {
                    adjustedTokenized.append(token.base)
                    print("adding \(token.dictionaryForm)")
                    resultSet.formUnion(exactSearchDatabase(for: token.dictionaryForm))
                } else {
                    if exactSearchDatabase(for: adjustedTokenized.last! + token.base).count >= 1 {
                        adjustedTokenized.append(adjustedTokenized.popLast()! + token.base)
                    } else {
                        particlesUnused.append(token.base)
                    }
                }
            } else {
                adjustedTokenized.append(token.base)
                if token.partOfSpeech == .verb {
                    resultSet.formUnion(exactSearchDatabase(for: token.dictionaryForm))
                }
                print("adding \(token.dictionaryForm)")
            }
        }
        
        print(adjustedTokenized)
        print(tokenized)
        for filteredWord in adjustedTokenized {
            resultSet.formUnion(exactSearchDatabase(for: filteredWord))
        }
        for particleUnused in particlesUnused {
            resultSet.formUnion(exactSearchDatabase(for: particleUnused))
        }
        return resultSet.sorted(by: {
            sortResults(a: $0, b: $1, searchString: searchString)
        })
    } catch {
        print("\(error) when tokenizing for partial search")
    }
    return []
}

@available(*, deprecated, renamed: "partialSearch", message: "Try not to use intensive search, this costs a lot of resources and grows exponentially as the string grows")
func doPartialSearch(searchString: String) -> [DatabaseWord] {
    var newPartialSearchCache: [String: Set<DatabaseWord>] = [:]
    return __partialSearch(searchString: searchString, partialSearchCache: &newPartialSearchCache).sorted(by: {
        sortResults(a: $0, b: $1, searchString: searchString)
    })
}

fileprivate func __partialSearch(searchString: String, originalSearchString: String? = nil, dropNumber: Int = 0, partialSearchCache: inout [String: Set<DatabaseWord>]) -> Set<DatabaseWord> {
//    if searchString.count <= 2 {
//        return []
//    }
    if partialSearchCache.keys.contains(searchString) {
        return partialSearchCache[searchString]!
    }
    if originalSearchString == nil && partialSearchGlobalCache.keys.contains(searchString) {
        return partialSearchGlobalCache[searchString]!
    }
    if searchString.isEmpty || (
        originalSearchString != nil &&
        (originalSearchString?.count ?? 0) - dropNumber - 1 < 1
    ){
        return []
    }
    print("Calling partial with \(searchString) \(originalSearchString ?? " ") \(dropNumber)")
    
    var searchResults: Set<DatabaseWord> = []
    searchResults.formUnion(exactSearchDatabase(for: searchString))
    
    let deconjugationAttempt = ConjugationManager.sharedInstance.deconjugate(searchString)
    for conjugation in deconjugationAttempt {
        if conjugation.verbDictionaryForm != searchString {
            var newPartialSearchCache: [String: Set<DatabaseWord>] = [:]
            searchResults.formUnion(__partialSearch(searchString: conjugation.verbDictionaryForm, partialSearchCache: &newPartialSearchCache))
        }
    }
    
    let focusString = (originalSearchString ?? searchString)
    let dropSearch = (__partialSearch(searchString: String(focusString.prefix(focusString.count - dropNumber - 1)), originalSearchString: originalSearchString ?? searchString, dropNumber: dropNumber + 1, partialSearchCache: &partialSearchCache))
    if !searchResults.isEmpty {
        var newPartialSearchCache: [String: Set<DatabaseWord>] = [:]
        let newSearchString = String(focusString.suffix(dropNumber))
        searchResults.formUnion(__partialSearch(searchString: newSearchString, partialSearchCache: &newPartialSearchCache))
    }
    searchResults.formUnion(dropSearch)
    
    partialSearchCache[searchString] = searchResults
    if originalSearchString == nil {
        partialSearchGlobalCache[searchString] = searchResults
    }
    return searchResults
}

func exactSearchDatabase(for searchString: String) -> Set<DatabaseWord> {
    var searchResults: Set<DatabaseWord> = []
    if let iterator = searchDatabase(databaseName: .jitendex, for: searchString, exact: true) {
        do {
            while let row = try iterator.failableNext() {
                let wordIndex = Table("wordIndex")
                let word = Table("word")
                let newWord = DatabaseWord(id: try! row.get(word[Expression<Int>("id")]),
                                           dict: .jitendex,
                                           word: try! row.get(wordIndex[Expression<String>("w")]),
                                           readingsString: try! row.get(word[Expression<String>("w")]),
                                           meaning: try! row.get(Expression<String>("m")))
                searchResults.insert(newWord)
            }
        } catch {
            print("error occurred when searching partially")
        }
    }
    return searchResults
}

func searchDatabase(databaseName dictName: DICTIONARY_NAMES, for searchString: String, exact: Bool = false) -> RowIterator? {
    do {
        let db = DatabaseConnections[dictName]!
        let wordIndex = VirtualTable("wordIndex")
        let word = Table("word")
        let id = Expression<Int>("id")
        let results: Expression<Bool> = (exact ? wordIndex.match("w:\"\(searchString)\" OR w:\"\(searchString.applyingTransform(.hiraganaToKatakana, reverse: false) ?? searchString)\" OR w:\"\(searchString.applyingTransform(.hiraganaToKatakana, reverse: true) ?? searchString)\" OR w:\"\(searchString.applyingTransform(.latinToHiragana, reverse: false) ?? searchString)\" OR w:\"\(searchString.applyingTransform(.latinToKatakana, reverse: false) ?? searchString)\"") : wordIndex.match("w:\"\(searchString)\"* OR w:\"\(searchString.applyingTransform(.hiraganaToKatakana, reverse: false) ?? searchString)\"* OR w:\"\(searchString.applyingTransform(.hiraganaToKatakana, reverse: true) ?? searchString)\"* OR w:\"\(searchString.applyingTransform(.latinToHiragana, reverse: false) ?? searchString)\"* OR w:\"\(searchString.applyingTransform(.latinToKatakana, reverse: false) ?? searchString)\"*"))
//        (exact ? wordIndex.match("w:\"\(searchString.applyingTransform(.hiraganaToKatakana, reverse: false) ?? searchString)\"") : wordIndex.match("w:\"\(searchString.applyingTransform(.hiraganaToKatakana, reverse: false) ?? searchString)\"*")) ||
//        (exact ? wordIndex.match("w:\"\(searchString.applyingTransform(.hiraganaToKatakana, reverse: true) ?? searchString)\"") : wordIndex.match("w:\"\(searchString.applyingTransform(.hiraganaToKatakana, reverse: true) ?? searchString)\"*")) ||
//        (exact ? wordIndex.match("w:\"\(searchString.applyingTransform(.latinToKatakana, reverse: false) ?? searchString)\"") : wordIndex.match("w:\"\(searchString.applyingTransform(.latinToKatakana, reverse: false) ?? searchString)\"*")) ||
//        (exact ? wordIndex.match("w:\"\(searchString.applyingTransform(.latinToHiragana, reverse: false) ?? searchString)\"") : wordIndex.match("w:\"\(searchString.applyingTransform(.latinToHiragana, reverse: false) ?? searchString)\"*"))
        return try db.prepareRowIterator(wordIndex.filter(results).join(word, on: word[id] == wordIndex[id]))
    } catch {
        return nil
    }
}

let specialCases = [
"…",
"-"
]

func findSimilarWord(databaseName dictName: DICTIONARY_NAMES, for searchStrings: [String]) -> (AnySequence<Row>, Int) {
    if searchStrings.count < 1 {
        return (AnySequence([]), 0)
    }
    do {
        let db = DatabaseConnections[dictName]!
        let word = Table("word")
        let w = Expression<String>("w")
        let firstSS = searchStrings.first!
        var results = __generateStrict(clm: w, searchString: firstSS)
        for searchString in searchStrings[1...] {
            results = results && __generateStrict(clm: w, searchString: searchString)
        }
        return (try db.prepare(word.filter(results).order(w.length)), try db.scalar(word.filter(results).count))
    } catch {
        return (AnySequence([]), 0)
    }
}

func __generateStrict(clm: Expression<String>, searchString: String) -> Expression<Bool> {
    func expr(s: String) -> Expression<Bool> {
        return clm.like("%|\(s)") || clm.like("\(s)|%") || clm.like("%|\(s)|%") || clm.like("\(s)")
    }
    var base = expr(s: searchString)
    for specialCase in specialCases {
        base = base || expr(s: "\(specialCase)\(searchString)") || expr(s: "\(searchString)\(specialCase)")
    }
    return base
}

extension String {
    var containsChineseCharacters: Bool {
        return self.range(of: "\\p{Han}", options: .regularExpression) != nil
    }
}
