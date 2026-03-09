import SwiftUI

struct KanjiDefinition: View {
    let key: SearchResultKey
    let dictionary: DictionaryProtocol?

    @State private var kanjiInfo: KanjiInfo?
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    KanjiHeaderCard(key: key, kanjiInfo: kanjiInfo)

                    DefinitionStatusView(isLoading: isLoading, errorMessage: errorMessage)

                    if let kanjiInfo {
                        KanjiDetailsSection(info: kanjiInfo)
                    }
                }
            }
            .padding()
            .textSelection(.enabled)
            .task(id: key.id + key.dictionaryName) {
                await loadDefinition()
            }
        }
    }

    private func loadDefinition() async {
        isLoading = true
        errorMessage = ""
        kanjiInfo = nil

        let result = await KanjiDefinitionUtilities.loadDefinition(key: key, dictionary: dictionary)
        kanjiInfo = result.kanjiInfo
        errorMessage = result.errorMessage

        isLoading = false
    }
}

#if DEBUG
#Preview {
    let dictionary = previewKanjiDictionary()
    let key = previewKanjiKey(using: dictionary)

    NavigationStack {
        KanjiDefinition(key: key, dictionary: dictionary)
    }
}

private func previewKanjiDictionary() -> (any DictionaryProtocol)? {
    if let bundled = KanjiDictSQLiteDictionary(name: "kanjidict2", bundle: .main) {
        return bundled
    }

    return createAvailableDictionaries()
        .first(where: { $0.name.lowercased().contains("kanjidict") })
}

private func previewKanjiKey(using dictionary: (any DictionaryProtocol)?) -> SearchResultKey {
    if let dictionary {
        var stream = dictionary.searchExact("生")
        if let key = stream.next() {
            return key
        }

        return SearchResultKey(
            id: "生",
            dictionaryName: dictionary.name,
            keyText: "生",
            keyId: 0,
            readings: []
        )
    }

    return SearchResultKey(
        id: "生",
        dictionaryName: "kanjidict2",
        keyText: "生",
        keyId: 0,
        readings: []
    )
}
#endif
