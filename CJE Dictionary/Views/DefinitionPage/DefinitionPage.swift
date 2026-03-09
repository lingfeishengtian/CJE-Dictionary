//
//  DefinitionPage.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/1/26.
//

import SwiftUI
import UIKit

struct DefinitionPage: View {
    let key: SearchResultKey
    let dictionary: DictionaryProtocol?

    @State private var definitionGroups: [DefinitionGroup] = []
    @State private var conjugations: [ConjugatedVerb] = []
    @State private var kanjiDictionaryMatches: [SearchResultKey] = []
    @State private var kanjiInfosByCharacter: [String: KanjiInfo] = [:]
    @State private var fallbackText: String?
    @State private var isLoading = false
    @State private var errorMessage = ""

    init(key: SearchResultKey, dictionary: DictionaryProtocol? = nil) {
        self.key = key
        self.dictionary = dictionary
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    DefinitionHeaderView(key: key)

                    if conjugations.count > 1 {
                        ConjugationViewer(conjugatedVerbs: conjugations)
                            .frame(height: 38, alignment: .center)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }

                    DefinitionStatusView(isLoading: isLoading, errorMessage: errorMessage)

                    if !definitionGroups.isEmpty {
                        DefinitionGroupsListView(definitionGroups: definitionGroups, screenWidth: geo.size.width)
                    } else if let fallbackText, !fallbackText.isEmpty, !isLoading {
                        DefinitionFallbackView(text: fallbackText)
                    }

                    if !kanjiDictionaryMatches.isEmpty {
                        KanjiInformationSectionView(
                            matches: kanjiDictionaryMatches,
                            kanjiInfosByCharacter: kanjiInfosByCharacter,
                            dictionary: kanjiDictionary()
                        )
                    }
                }
            }
            .padding()
            .textSelection(.enabled)
            .navigationTitle(key.keyText)
            .task(id: key.id + key.dictionaryName) {
                await loadDefinition()
            }
        }
    }

    private func loadDefinition() async {
        isLoading = true
        errorMessage = ""
        definitionGroups = []
        conjugations = []
        kanjiInfosByCharacter = [:]
        fallbackText = nil

        guard let dictionary else {
            errorMessage = "Dictionary context unavailable for this result."
            isLoading = false
            return
        }

        do {
            definitionGroups = try await dictionary.getDefinitionGroups(fromKey: key)
            conjugations = buildConjugations(from: definitionGroups, word: key.keyText)
        } catch {
            errorMessage = error.localizedDescription
        }

        if definitionGroups.isEmpty,
           let recordData = dictionary.getRecordData(fromKey: key),
           let html = String(data: recordData, encoding: .utf8)
            ?? String(data: recordData, encoding: .utf16)
            ?? String(data: recordData, encoding: .unicode) {
            fallbackText = htmlToPlainText(html)
        }

        let activeKanjiDictionary = kanjiDictionary()
        kanjiDictionaryMatches = KanjiSectionDataLoader.loadMatches(from: key, using: activeKanjiDictionary)
        kanjiInfosByCharacter = KanjiSectionDataLoader.loadInfos(for: kanjiDictionaryMatches, using: activeKanjiDictionary)

        isLoading = false
    }

    private func buildConjugations(from groups: [DefinitionGroup], word: String) -> [ConjugatedVerb] {
        var tagSet: Set<Tag> = []
        groups.forEach { tagSet.formUnion($0.tags) }

        var bestConjugations: [ConjugatedVerb] = []
        for tag in tagSet {
            let result = ConjugationManager.sharedInstance.conjugate(word, verbType: tag.shortName)
            if result.count > bestConjugations.count {
                bestConjugations = result
            }
        }

        return bestConjugations
    }

    private func htmlToPlainText(_ html: String) -> String {
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              )
        else {
            return html
        }

        return attributed.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func kanjiDictionary() -> (any DictionaryProtocol)? {
        if key.dictionaryName.lowercased().contains("kanjidict") {
            return dictionary
        }

        return createAvailableDictionaries()
            .first(where: { $0.name.lowercased().contains("kanjidict") })
    }
}

#Preview {
    return NavigationStack {
        if let dictionary = createAvailableDictionaries().first {
            let searchWord = "為る"
            var stream = dictionary.searchExact(searchWord)
            let previewKey = stream.next()
                ?? {
                    var fallbackStream = dictionary.searchPrefix(searchWord)
                    return fallbackStream.next()
                }()
                ?? SearchResultKey(
                    id: searchWord,
                    dictionaryName: dictionary.name,
                    keyText: searchWord,
                    keyId: 0,
                    readings: [searchWord]
                )

            DefinitionPage(key: previewKey, dictionary: dictionary)
        } else {
            Text("Could not load any dictionary for preview.")
                .foregroundStyle(.red)
                .padding()
        }
    }
}
