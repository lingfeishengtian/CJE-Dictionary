//
//  DefinitionPage.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/1/26.
//

import SwiftUI

struct DefinitionPage: View {
    let key: SearchResultKey
    let dictionary: DictionaryProtocol?

    @StateObject private var viewModel: DefinitionPageViewModel

    init(key: SearchResultKey, dictionary: DictionaryProtocol? = nil) {
        self.key = key
        self.dictionary = dictionary
        _viewModel = StateObject(wrappedValue: DefinitionPageViewModel(key: key, dictionary: dictionary))
    }

    var body: some View {
        definitionTabContent
        .navigationTitle(viewModel.key.keyText)
        .task(id: viewModel.key.id + viewModel.key.dictionaryName) {
            await viewModel.loadDefinition()
        }
    }

    private var definitionTabContent: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    DefinitionHeaderView(key: viewModel.key)

                    if !viewModel.crossDictionaryOptions.isEmpty {
                        Picker("Dictionary", selection: $viewModel.selectedDictionaryOptionID) {
                            Text(viewModel.key.dictionaryName).tag(viewModel.currentDictionaryOptionID)
                            ForEach(viewModel.crossDictionaryOptions) { option in
                                Text(option.name)
                                    .tag(option.id)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.selectedDictionaryOptionID) { newID in
                            Task {
                                await viewModel.dictionarySelectionChanged(to: newID)
                            }
                        }
                    }

                    if viewModel.conjugations.count > 1 {
                        ConjugationViewer(conjugatedVerbs: viewModel.conjugations)
                            .frame(height: 38, alignment: .center)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }

                    DefinitionStatusView(isLoading: viewModel.displayedIsLoading, errorMessage: viewModel.displayedErrorMessage)

                    if !viewModel.displayedDefinitionGroups.isEmpty {
                        DefinitionGroupsListView(definitionGroups: viewModel.displayedDefinitionGroups, screenWidth: geo.size.width)
                    } else if let displayedFallbackText = viewModel.displayedFallbackText,
                              !displayedFallbackText.isEmpty,
                              !viewModel.displayedIsLoading {
                        DefinitionFallbackView(text: displayedFallbackText)
                    }

                    if viewModel.selectedDictionaryOptionID != viewModel.currentDictionaryOptionID,
                       let selectedCandidates = viewModel.selectedCrossCandidates,
                       !selectedCandidates.isEmpty {
                        Picker("Word", selection: Binding(
                            get: { viewModel.selectedCrossCandidateID ?? "" },
                            set: { newID in
                                Task {
                                    await viewModel.candidateSelectionChanged(newID, for: viewModel.selectedDictionaryOptionID)
                                }
                            }
                        )) {
                            ForEach(selectedCandidates) { candidate in
                                Text("\(candidate.key.keyText) • \(candidate.confidenceText) \(candidate.confidenceLevel)")
                                    .tag(candidate.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if !viewModel.kanjiDictionaryMatches.isEmpty {
                        KanjiInformationSectionView(
                            matches: viewModel.kanjiDictionaryMatches,
                            kanjiInfosByCharacter: viewModel.kanjiInfosByCharacter,
                            dictionary: viewModel.kanjiDictionaryForDisplay
                        )
                    }
                }
            }
            .padding()
            .textSelection(.enabled)
        }
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
