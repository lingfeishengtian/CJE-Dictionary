import Foundation

@MainActor
final class DefinitionPageViewModel: ObservableObject {
    let key: SearchResultKey
    let dictionary: DictionaryProtocol?
    let currentDictionaryOptionID = "__current_dictionary__"

    @Published var definitionGroups: [DefinitionGroup] = []
    @Published var conjugations: [ConjugatedVerb] = []
    @Published var kanjiDictionaryMatches: [SearchResultKey] = []
    @Published var kanjiInfosByCharacter: [String: KanjiInfo] = [:]
    @Published var fallbackText: String?
    @Published var isLoading = false
    @Published var errorMessage = ""

    @Published var crossDictionaryOptions: [CrossDictionaryOption] = []
    @Published var crossCandidatesByDictionary: [String: [CrossDictionaryCandidate]] = [:]
    @Published var selectedCrossCandidateIDByDictionary: [String: String] = [:]
    @Published var selectedDictionaryOptionID: String
    @Published var crossDefinitionGroups: [DefinitionGroup] = []
    @Published var crossFallbackText: String?
    @Published var isLoadingCrossDefinition = false
    @Published var crossErrorMessage = ""

    init(key: SearchResultKey, dictionary: DictionaryProtocol? = nil) {
        self.key = key
        self.dictionary = dictionary
        self.selectedDictionaryOptionID = currentDictionaryOptionID
    }

    var displayedDefinitionGroups: [DefinitionGroup] {
        selectedDictionaryOptionID == currentDictionaryOptionID ? definitionGroups : crossDefinitionGroups
    }

    var displayedFallbackText: String? {
        selectedDictionaryOptionID == currentDictionaryOptionID ? fallbackText : crossFallbackText
    }

    var displayedIsLoading: Bool {
        selectedDictionaryOptionID == currentDictionaryOptionID ? isLoading : isLoadingCrossDefinition
    }

    var displayedErrorMessage: String {
        selectedDictionaryOptionID == currentDictionaryOptionID ? errorMessage : crossErrorMessage
    }

    var selectedCrossCandidates: [CrossDictionaryCandidate]? {
        crossCandidatesByDictionary[selectedDictionaryOptionID]
    }

    var selectedCrossCandidateID: String? {
        selectedCrossCandidateIDByDictionary[selectedDictionaryOptionID]
    }

    var kanjiDictionaryForDisplay: (any DictionaryProtocol)? {
        kanjiDictionary()
    }

    func loadDefinition() async {
        isLoading = true
        resetAllState()

        guard let dictionary else {
            errorMessage = "Dictionary context unavailable for this result."
            isLoading = false
            return
        }

        let definitionResult = await DefinitionContentLoadUtility.loadDefinition(
            dictionary: dictionary,
            key: key
        )
        definitionGroups = definitionResult.groups
        fallbackText = definitionResult.fallbackText
        errorMessage = definitionResult.errorMessage ?? ""
        conjugations = buildConjugations(from: definitionGroups, word: key.keyText)

        let activeKanjiDictionary = kanjiDictionary()
        kanjiDictionaryMatches = KanjiSectionDataLoader.loadMatches(from: key, using: activeKanjiDictionary)
        kanjiInfosByCharacter = KanjiSectionDataLoader.loadInfos(for: kanjiDictionaryMatches, using: activeKanjiDictionary)

        loadCrossDictionaryOptions()

        isLoading = false
    }

    func dictionarySelectionChanged(to newID: String) async {
        guard newID != currentDictionaryOptionID else { return }
        await ensureCrossDictionaryLoaded(for: newID)
    }

    func candidateSelectionChanged(_ candidateID: String, for dictionaryID: String) async {
        updateSelectedCrossCandidateID(candidateID, for: dictionaryID)
        await loadCrossDefinition(for: dictionaryID)
    }

    private func loadCrossDictionaryOptions() {
        crossDictionaryOptions = CrossDictionarySearchUtility.makeOptions(
            key: key,
            currentDictionary: dictionary
        )

        if selectedDictionaryOptionID != currentDictionaryOptionID,
           !crossDictionaryOptions.contains(where: { $0.id == selectedDictionaryOptionID }) {
            selectedDictionaryOptionID = currentDictionaryOptionID
        }
    }

    private func ensureCrossDictionaryLoaded(for dictionaryID: String) async {
        if crossCandidatesByDictionary[dictionaryID] != nil {
            await loadCrossDefinition(for: dictionaryID)
            return
        }

        guard let selectedDictionary = crossDictionaryOptions.first(where: { $0.id == dictionaryID })?.dictionary else {
            return
        }

        let candidates = CrossDictionarySearchUtility.buildCandidates(
            for: selectedDictionary,
            key: key
        )

        crossCandidatesByDictionary[dictionaryID] = candidates

        if let top = candidates.first {
            selectedCrossCandidateIDByDictionary[dictionaryID] = top.id
            await loadCrossDefinition(for: dictionaryID)
        } else {
            resetCrossDisplayedContent()
            crossErrorMessage = "No cross-search result in \(selectedDictionary.name)."
        }
    }

    private func loadCrossDefinition(for dictionaryID: String) async {
        guard let candidates = crossCandidatesByDictionary[dictionaryID],
              let selectedCandidateID = selectedCrossCandidateIDByDictionary[dictionaryID],
              let candidate = candidates.first(where: { $0.id == selectedCandidateID }) else {
            return
        }

        isLoadingCrossDefinition = true
        crossErrorMessage = ""
        resetCrossDisplayedContent()

        let result = await CrossDictionarySearchUtility.loadDefinition(for: candidate)
        crossDefinitionGroups = result.groups
        crossFallbackText = result.fallbackText
        crossErrorMessage = result.errorMessage ?? ""

        isLoadingCrossDefinition = false
    }

    private func updateSelectedCrossCandidateID(_ candidateID: String, for dictionaryID: String) {
        selectedCrossCandidateIDByDictionary[dictionaryID] = candidateID
    }

    private func resetAllState() {
        errorMessage = ""
        definitionGroups = []
        conjugations = []
        kanjiDictionaryMatches = []
        kanjiInfosByCharacter = [:]
        fallbackText = nil

        crossDictionaryOptions = []
        crossCandidatesByDictionary = [:]
        selectedCrossCandidateIDByDictionary = [:]
        selectedDictionaryOptionID = currentDictionaryOptionID
        isLoadingCrossDefinition = false
        crossErrorMessage = ""
        resetCrossDisplayedContent()
    }

    private func resetCrossDisplayedContent() {
        crossDefinitionGroups = []
        crossFallbackText = nil
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

    private func kanjiDictionary() -> (any DictionaryProtocol)? {
        if key.dictionaryName.lowercased().contains("kanjidict") {
            return dictionary
        }

        return createAvailableDictionaries()
            .first(where: { $0.name.lowercased().contains("kanjidict") })
    }
}
