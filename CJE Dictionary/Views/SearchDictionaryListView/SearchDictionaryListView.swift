//
//  SearchDictionaryListView.swift
//  CJE Dictionary
//
//

import SwiftUI
import Foundation

/// Full search view backed by a DictionaryProtocol. No debounce: searches run on every text change.
struct SearchDictionaryListView: View {
    let dictionary: DictionaryProtocol
    @State private var query = ""
    @StateObject private var streamManager = SearchStreamManager()

    init(dictionary: DictionaryProtocol) {
        self.dictionary = dictionary
        // initialize the StateObject with empty manager; we'll reset on first search
        _streamManager = StateObject(wrappedValue: SearchStreamManager())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                SearchBar(text: $query)
                    .onChange(of: query, perform: runSearch)

                if streamManager.results.isEmpty {
                    Spacer()
                    Text(query.isEmpty ? "Start typing to search" : "No results")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    SearchResultsView(streamManager: streamManager)
                }
            }
            .navigationTitle(dictionary.name)
        }
    }

    private func runSearch(_ s: String) {
        if s.isEmpty {
            streamManager.reset(with: nil)
            return
        }

        let prioritizedQueries = buildPrioritizedQueries(from: s)
        let streams = prioritizedQueries.map { query in
            dictionary.searchPrefix(query)
        }
        let stream = CombinedDictionaryStream(streams: streams)

        streamManager.dictionaryForPreview = dictionary
        streamManager.reset(with: stream)
    }

    private func buildPrioritizedQueries(from input: String) -> [String] {
        let normalizedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedInput.isEmpty {
            return []
        }

        var queries: [String] = []

        func appendUnique(_ candidate: String?) {
            guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return
            }
            if !queries.contains(value) {
                queries.append(value)
            }
        }

        let hiragana = normalizedInput.applyingTransform(.latinToHiragana, reverse: false)
            ?? normalizedInput.applyingTransform(.hiraganaToKatakana, reverse: true)
        let katakana = hiragana?.applyingTransform(.hiraganaToKatakana, reverse: false)
            ?? normalizedInput.applyingTransform(.latinToKatakana, reverse: false)
            ?? normalizedInput.applyingTransform(.hiraganaToKatakana, reverse: false)
        let romaji = normalizedInput
            .applyingTransform(.toLatin, reverse: false)?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")

        // Priority order requested: input, hiragana, katakana, romaji
        appendUnique(normalizedInput)
        appendUnique(hiragana)
        appendUnique(katakana)
        appendUnique(romaji)

        return queries
    }
}

// SearchResultsView and DefinitionPage are implemented in separate files.

// MARK: - Preview supporting mock
struct SearchDictionaryListView_Previews: PreviewProvider {
    struct MockDict: DictionaryProtocol {
        var name: String = "Mock"
        var type: LanguageToLanguage = LanguageToLanguage(searchLanguage: .JP, resultsLanguage: .EN)
        func searchExact(_ searchString: String) -> DictionaryStreamProtocol { DictionaryStream(keys: [SearchResultKey(id: "1", dictionaryName: "mock", keyText: searchString, keyId: 1)]) }
        func searchPrefix(_ prefix: String) -> DictionaryStreamProtocol {
            // Try to initialize MdictOptimized from bundle FST/rd/def files (jitendex.*)
            // Try bundle first, then look in repository root (useful for previews)
            var fstPath: String? = Bundle.main.path(forResource: "jitendex", ofType: "fst")
            var rdPath: String? = Bundle.main.path(forResource: "jitendex", ofType: "rd")
            var defPath: String? = Bundle.main.path(forResource: "jitendex", ofType: "def")
            if fstPath == nil || rdPath == nil || defPath == nil {
                if let src = ProcessInfo.processInfo.environment["SRCROOT"] {
                    let base = URL(fileURLWithPath: src).appendingPathComponent("Resources")
                    let tryFst = base.appendingPathComponent("jitendex.fst").path
                    let tryRd = base.appendingPathComponent("jitendex.rd").path
                    let tryDef = base.appendingPathComponent("jitendex.def").path
                    if FileManager.default.fileExists(atPath: tryFst) && FileManager.default.fileExists(atPath: tryRd) && FileManager.default.fileExists(atPath: tryDef) {
                        fstPath = tryFst
                        rdPath = tryRd
                        defPath = tryDef
                    }
                }
            }

            if let fst = fstPath, let rd = rdPath, let def = defPath {
                if let optimized = MdictOptimizedManager.createOptimized(fromBundle: "", fstPath: fst, readingsPath: rd, recordPath: def) {
                    let dict = MdictOptimizedDictionary(name: "jitendex", type: type, optimizedMdict: optimized)
                    return dict.searchPrefix(prefix)
                }
            }

            // fallback: generate 200 sample SearchResultKey objects for preview/testing
            let keys: [SearchResultKey] = (0..<200).map { i in
                SearchResultKey(id: "\(i)", dictionaryName: "mock", keyText: "\(prefix)-\(i)", keyId: Int64(i), readings: (i % 5 == 0) ? ["r\(i)"] : nil)
            }
            return DictionaryStream(keys: keys)
        }
        func getWord(byId id: AnyHashable) -> Word? { Word(id: String(describing: id), dict: .jitendex, word: "Word \(id)", readings: ["r1"]) }
        func getWord(fromKey key: SearchResultKey) -> Word? { Word(id: key.id, dict: .jitendex, word: key.keyText, readings: key.readings ?? []) }
    }

    static var previews: some View {
        SearchDictionaryListView(dictionary: MockDict())
    }
}
