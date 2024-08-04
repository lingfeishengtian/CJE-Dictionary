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
import OrderedCollections

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

let realm: Realm = try! Realm(configuration: CONFIGURATION)

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
            // ENSURE SEARCH IS USING INDEX
            //            let plan = try dbConnection.prepareRowIterator("EXPLAIN QUERY PLAN SELECT * FROM wordIndex INNER JOIN \"word\" USING (\"id\") WHERE wort LIKE \"あ%\";")
            //            while let a = plan.next() {
            //                print(a)
            //            }
            
            // Substring works differently here, you need to -1 at the end for some reason
            try dbConnection.execute("""
            CREATE TABLE "wordIndex" (
                            "id"    INTEGER NOT NULL,
                            "wort"    TEXT NOT NULL,
                            FOREIGN KEY(id) REFERENCES word(id)
                        );
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
                            INSERT INTO wordIndex (id, wort)
                            SELECT id, w
                            FROM cte
                            WHERE w <> '';
            DELETE FROM wordIndex WHERE wort LIKE "%【%】%";
            CREATE INDEX wordIndex_w_idx ON wordIndex(wort COLLATE NOCASE);
            ANALYZE;
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

class DatabaseWord: Hashable, Codable {
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
    //title CONTAINS[c] "同:" OR title contains[c] "同："
    //    guard let wordDef = getDefinition(databasename: word.dict, for: word.id) else {
    //        return CJE_Definition(word: word, definitions: [])
    //    }
    print("Start lookup: \(Date.now.timeIntervalSince1970)")
    for dict in DICTIONARY_NAMES.allCases {
        var priority = -1
        if dict.type().1 == .CN {
            var potential: (LanguageToLanguage, [DefinitionGroup]) = (dict.type(), [])
            let readingsContainsKanji = word.readings.contains(where: { $0.containsKanjiCharacters })
            for reading in word.readings {
                let existsInRealm = realm.objects(Wort.self).where { realmObj in
                    realmObj.spell == reading.trimmingCharacters(in: ["-", "…"])
                }
                let rPrio = reading.containsChineseCharacters ? 2 : 1
                let kanjiFindPron = reading.containsKanjiCharacters ? existsInRealm.filter({ wort in
                    word.readings.contains(where: { wort.pron == $0.trimmingCharacters(in: ["-", "…"]) })
                }).sorted(by: {
                    if $0.pron == word.word {
                        return true
                    } else if $1.pron == word.word {
                        return false
                    } else {
                        return $0.pron ?? "" > $1.pron ?? ""
                    }
                }) : nil
                if !existsInRealm.isEmpty && priority <= rPrio && (!readingsContainsKanji || kanjiFindPron != nil) {
                    for realmWort in kanjiFindPron?.uniqueElements ?? [existsInRealm.first!] {
                        var tags: [Tag] = []
                        
                        for detail in realm.objects(Details.self).where({
                            $0.wordId == realmWort.objectId
                        }) {
                            if !(detail.title?.isEmpty ?? true) {
                                tags.append(Tag(shortName: detail.title ?? "", longName: detail.title ?? ""))
                            }
                        }
                        
                        let realmDefinitions = realm.objects(Subdetails.self).where {
                            $0.wordId == realmWort.objectId
                        }
                        
                        // Special case where realm definition gives only one 同：
                        if realmDefinitions.count == 1 {
                            if realmDefinitions.first!.title?.starts(with: "同：") ?? false || realmDefinitions.first!.title?.starts(with: "同:") ?? false {
                                continue
                            }
                        }
                        
                        let definitions: [Definition] = realmDefinitions.map({ subdetail in
                            var exampleSentences: [ExampleSentence] = []
                            
                            for example in realm.objects(Example.self).where({
                                $0.subdetailsId == subdetail.objectId
                            }) {
                                exampleSentences.append(ExampleSentence(language: .JP, attributedString: AttributedString(example.title ?? "")))
                                exampleSentences.append(ExampleSentence(language: .CN, attributedString: AttributedString(example.trans ?? "")))
                            }
                            
                            return Definition(definition: subdetail.title ?? "", exampleSentences: exampleSentences)
                        })
                        
                        priority = rPrio
                        potential = (dict.type(), [DefinitionGroup(tags: tags, definitions: definitions)])
                    }
                }
            }
            
            if priority >= 1 {
                finDefs.append(potential)
                continue
            }
        }
        print("End lookup moji: \(Date.now.timeIntervalSince1970)")
        if dict == word.dict {
            print("Start parsing \(Date.now.timeIntervalSince1970)")
            finDefs.append((dict.type(), word.parseDefinitionHTML()))
            print("End parsing \(Date.now.timeIntervalSince1970)")
            continue
        }
        print("Start lookup for \(dict.type().1.rawValue): \(Date.now.timeIntervalSince1970)")
        let wordList = eliminateSpecialCasesFromWordlist(wordList: word.readings)
        do {
            let res: [DatabaseWord] = __lookupWordHelper(wordList: wordList, dict: dict)
            // Word, Percent Match, Number of Readings
            var finalList: [(DatabaseWord, Double, Int)] = []
            // Sort words by highest match
            for possibleWord in res {
                let numReadings = possibleWord.readings.count
                var readingsExists = 0
                for reading in eliminateSpecialCasesFromWordlist(wordList: possibleWord.readings) {
                    if wordList.contains(reading) {
                        readingsExists += 1
                    }
                }
                
                finalList.append((possibleWord, Double(readingsExists)/Double(numReadings), numReadings))
            }
            
            finalList = finalList.sorted(by: { a, b in
                if a.1 == b.1 {
                    return a.2 > b.2
                } else {
                    return a.1 > b.1
                }
            })
            
            if finalList.count > 0 {
                finDefs.append((dict.type(), word.parseDefinitionHTML(otherHTML: finalList.first?.0.meaning)))
            }
        }
        print("End lookup for \(dict.type().1.rawValue): \(Date.now.timeIntervalSince1970)")
    }
    print("End lookup final: \(Date.now.timeIntervalSince1970)")
    return CJE_Definition(word: word, definitions: finDefs)
}

func eliminateSpecialCasesFromWordlist(wordList: [String]) -> [String] {
    let specialCases = ["…", "-"]
    var result = wordList
    for var res in result {
        for specialCase in specialCases {
            res = res.replacingOccurrences(of: specialCase, with: "")
        }
    }
    return result
}

fileprivate func __lookupWordHelper(wordList: [String], dict: DICTIONARY_NAMES) -> [DatabaseWord] {
    var words = [DatabaseWord]()
    for word in wordList {
        let iterator = searchDatabaseExact(databaseName: dict, for: word)
        while let row = iterator?.next() {
            words.append(DatabaseWord(id: try! row.get(Expression<Int>("id")),
                                      dict: dict,
                                      word: try! row.get(Expression<String>("wort")),
                                      readingsString: try! row.get(Expression<String>("w")),
                                      meaning: try! row.get(Expression<String>("m"))))
        }
    }
    return words
}

class SearchResultsEnumerator: ObservableObject {
    var sQueryIterators: [(DICTIONARY_NAMES, RowIterator)] = []
    let pollingLimit: Int
    @Published var lazyArray: [DatabaseWord]
    let id: UUID = UUID()
    
    // TODO: multi squery support
    init(pollingLimit:Int = 10) {
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
            let statsTimeStart = Date.now
            do {
                if sQueryIterators.isEmpty {
                    return
                }
                
                guard let row = try sQueryIterators.first?.1.failableNext() else {
                    sQueryIterators.removeFirst()
                    continue
                }
                
                let newWord = DatabaseWord(id: try! row.get(Expression<Int>("id")),
                                           dict: sQueryIterators.first!.0,
                                           word: try! row.get(Expression<String>("wort")),
                                           readingsString: try! row.get(Expression<String>("w")),
                                           meaning: try! row.get(Expression<String>("m")))
                let msToRun = (Date.now.timeIntervalSince(statsTimeStart) * 1000 * 1000).rounded() / 1000
                if msToRun > 1 {
                    print("TOO LONG")
                }
                print("\(msToRun) ms to add word \(newWord.word)")
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
    for dict in [DICTIONARY_NAMES.jitendex] {
        let iterators = searchDatabaseGeneral(databaseName: dict, for: searchString)
        for f in iterators {
            if let it = f {
                ret.initSQueryForDict(dict: dict, sQuery: it)
            }
        }
    }
    return ret
}

var partialSearchGlobalCache: [String: Set<DatabaseWord>] = [:]
let ipadic=IPADic()

func partialSearch(searchQuery: String) -> [DatabaseWord] {
    guard let searchString = searchQuery.applyingTransform(.latinToHiragana, reverse: false) else {
        return []
    }
    
    do {
        let tokenizer = try Tokenizer(dictionary: ipadic)
        let tokenized = tokenizer.tokenize(text: searchString)
            .filter({ $0.partOfSpeech != .prefix })
        var adjustedTokenized: [String] = []
        var resultSet: OrderedSet<DatabaseWord> = []
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
                    resultSet.append(contentsOf: exactSearchDatabase(for: token.dictionaryForm))
                } else {
                    if exactSearchDatabase(for: adjustedTokenized.last! + token.base).count >= 1 {
                        adjustedTokenized.append(adjustedTokenized.popLast()! + token.base)
                    } else {
                        particlesUnused.append(token.base)
                    }
                }
            } else {
                adjustedTokenized.append(token.base)
                if token.partOfSpeech != .unknown && token.partOfSpeech != .particle {
                    resultSet.append(contentsOf: exactSearchDatabase(for: token.dictionaryForm))
                }
                print("adding \(token.dictionaryForm)")
            }
        }
        
        print(adjustedTokenized)
        print(tokenized)
        for filteredWord in adjustedTokenized {
            resultSet.append(contentsOf: exactSearchDatabase(for: filteredWord))
        }
        for particleUnused in particlesUnused {
            resultSet.append(contentsOf: exactSearchDatabase(for: particleUnused))
        }
        return resultSet.elements
        //            .sorted(by: {
        //            sortResults(a: $0, b: $1, searchString: searchString)
        //        })
    } catch {
        print("\(error) when tokenizing for partial search")
    }
    return []
}

func exactSearchDatabase(for searchString: String) -> Set<DatabaseWord> {
    var searchResults: Set<DatabaseWord> = []
    if let iterator = searchDatabaseExact(databaseName: .jitendex, for: searchString) {
        do {
            while let row = try iterator.failableNext() {
                let wordIndex = Table("wordIndex")
                let word = Table("word")
                let newWord = DatabaseWord(id: try! row.get(Expression<Int>("id")),
                                           dict: .jitendex,
                                           word: try! row.get(Expression<String>("wort")),
                                           readingsString: try! row.get(Expression<String>("w")),
                                           meaning: try! row.get(Expression<String>("m")))
                searchResults.insert(newWord)
            }
        } catch {
            print("error occurred when searching partially \(error)")
        }
    }
    return searchResults
}

fileprivate func __generateSQLiteQuery(for searchString: String, exact: Bool = false) -> [String] {
    let stringTranformations = Set([
        searchString.applyingTransform(.hiraganaToKatakana, reverse: false),
        searchString.applyingTransform(.hiraganaToKatakana, reverse: true),
        searchString.applyingTransform(.latinToHiragana, reverse: false),
        searchString.applyingTransform(.latinToKatakana, reverse: false)
    ])
    print(stringTranformations)
    
    var finalQueries: [String] = []
    
    for transformation in stringTranformations {
        guard let string = transformation else {
            continue
        }
        finalQueries.append("SELECT * FROM wordIndex INNER JOIN \"word\" USING (\"id\") WHERE wort LIKE '\(string + (exact ? "" : "%"))'")
    }
        
    return finalQueries
}

let DEBUG_DATABASE = 0

func searchDatabaseExact(databaseName dictName: DICTIONARY_NAMES, for searchString: String) -> RowIterator? {
    do {
        let db = DatabaseConnections[dictName]
        let query = "SELECT * FROM wordIndex INNER JOIN \"word\" USING (\"id\") WHERE wort LIKE '\(searchString)'"
        if DEBUG_DATABASE != 0 {
            try db?.prepare("explain query plan " + query).forEach { a in
                print(a)
            }
        }
        return try db?.prepareRowIterator(query)
    } catch {
        return nil
    }
}

func searchDatabaseGeneral(databaseName dictName: DICTIONARY_NAMES, for searchString: String) -> [RowIterator?] {
    do {
        let db = DatabaseConnections[dictName]
        let queries = __generateSQLiteQuery(for: searchString, exact: false).sorted(by: { $0.levenshteinDistanceScore(to: searchString) > $1.levenshteinDistanceScore(to: searchString) })
        var iterators: [RowIterator?] = []
        for query in queries {
            if DEBUG_DATABASE != 0 {
                try db?.prepare("explain query plan " + query).forEach { a in
                    print(a)
                }
            }
            iterators.append(try db?.prepareRowIterator(query))
        }
        return iterators
    } catch {
        return []
    }
}

extension String {
    func levenshteinDistanceScore(to string: String, ignoreCase: Bool = true, trimWhiteSpacesAndNewLines: Bool = true) -> Double {
        
        var firstString = self
        var secondString = string
        
        if ignoreCase {
            firstString = firstString.lowercased()
            secondString = secondString.lowercased()
        }
        if trimWhiteSpacesAndNewLines {
            firstString = firstString.trimmingCharacters(in: .whitespacesAndNewlines)
            secondString = secondString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let empty = [Int](repeating:0, count: secondString.count)
        var last = [Int](0...secondString.count)
        
        for (i, tLett) in firstString.enumerated() {
            var cur = [i + 1] + empty
            for (j, sLett) in secondString.enumerated() {
                cur[j + 1] = tLett == sLett ? last[j] : Swift.min(last[j], last[j + 1], cur[j])+1
            }
            last = cur
        }
        
        // maximum string length between the two
        let lowestScore = max(firstString.count, secondString.count)
        
        if let validDistance = last.last {
            return  1 - (Double(validDistance) / Double(lowestScore))
        }
        
        return 0.0
    }
    
    var containsChineseCharacters: Bool {
        return self.range(of: "\\p{Han}", options: .regularExpression) != nil
    }
}

