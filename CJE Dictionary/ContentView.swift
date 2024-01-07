//
//  ContentView.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/30/23.
//

import SwiftUI

extension GeometryProxy {
    var maxWidth: CGFloat {
        size.width - safeAreaInsets.leading - safeAreaInsets.trailing
    }
}

fileprivate struct ExampleSentenceTextView: View {
    let attributedString: AttributedString
    let screenWidth: CGFloat

    init(attributedString: AttributedString, screenWidth: CGFloat, language: Language) {
        let fontFamilyNames = UIFont.familyNames
        var flagEmoji: String {
            switch language {
            case .CN:
                "🇨🇳"
            case .EN:
                "🇺🇸"
            case .JP:
                "🇯🇵"
            }
        }
        var beginning = AttributedString(stringLiteral: flagEmoji + " ")
        var attrString = attributedString
        beginning.append(attrString)
        beginning.mergeAttributes(try! AttributeContainer([.font: UIFont(name: "HiraMinProN-W3", size: 15)!], including: \.uiKit))
        self.attributedString = beginning
        self.screenWidth = screenWidth
    }
    
    var body: some View {
        RubyDisplay(attributedString: attributedString, screenWidth: screenWidth)
    }
}

struct NavigationLazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

class SearchEnumeratorWrapper: ObservableObject {
    @Published var searchEnumerator: SearchResultsEnumerator? = nil
    var partialSearch: [DatabaseWord] = []
    
    var lazyArray: [DatabaseWord] {
        searchEnumerator?.lazyArray ?? []
    }
    
    func addToLazyArray() {
        if let e = searchEnumerator {
            e.addToLazyArray()
            objectWillChange.send()
        }
    }
}

struct DefinitionView: View {
    let dbWord: DatabaseWord
    let screenWidth: CGFloat
    private let wordLookup: [(LanguageToLanguage, [DefinitionGroup])]
    private let conjugations: [ConjugatedVerb]
    @State var selectedLangugae: Language
    
    init(dbWord: DatabaseWord, screenWidth: CGFloat) {
        self.dbWord = dbWord
        self.screenWidth = screenWidth
        self.wordLookup = lookupWord(word: dbWord).definitions
        self.selectedLangugae = wordLookup.first!.0.1
        
        var conj: [ConjugatedVerb] = []
        if let enDefs = wordLookup.first(where: { $0.0.1 == .EN }) {
            var tagSet: Set<Tag> = []
            enDefs.1.forEach({ tagSet.formUnion($0.tags) })
            
            for tag in tagSet {
                let c = ConjugationManager.sharedInstance.conjugate(dbWord.word, verbType: tag.shortName)
                if !c.isEmpty {
                    conj = c
                }
            }
        }
        
        self.conjugations = conj
        print(conjugations)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                RubyDisplay(attributedString: dbWord.generateAttributedStringTitle(), screenWidth: screenWidth)
                    .padding([.top], 10)
                if conjugations.count > 1 {
                    ConjugationViewer(conjugatedVerbs: conjugations).padding([.bottom], 10)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                Picker("Language", selection: $selectedLangugae) {
                    ForEach(Language.allCases) { lang in
                        if wordLookup.contains(where: { $0.0.1 == lang }) {
                            Text(LocalizedStringKey(lang.rawValue)).tag(lang)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding([.leading, .trailing], 20)
                ForEach(wordLookup.first(where: { $0.0.1 == selectedLangugae })!.1) { definitionGroup in
                    HStack {
                        ForEach(definitionGroup.tags) { tag in
                            Text(tag.longName)
                                .font(Font.caption2)
                                .padding(7)
                                .background(Color(.gray).brightness(-0.3))
                                .clipShape(.rect(cornerRadius: 16))
                                .padding([.trailing], 2)
                        }
                    }.padding([.leading, .trailing], 20)
                    if definitionGroup.tags.isEmpty {
                        Spacer(minLength: 7)
                    }
                    ForEach(0..<definitionGroup.definitions.count, id: \.self) { index in
                        let definition = definitionGroup.definitions[index]
                        Text("\(index + 1). \(definition.definition)")
                            .padding([.bottom], 5)
                            .contentMargins(10)
                            // .background(Color(.green))
                            // .clipShape(.rect(cornerRadius: 16))
                            .padding([.leading, .trailing], 20)
//                        if !definition.exampleSentences.isEmpty {
//                            Spacer(minLength: 20)
//                        }
                        ForEach(definition.exampleSentences) { elem in
                            ExampleSentenceTextView(attributedString: elem.attributedString, screenWidth: screenWidth, language: elem.language)
                                .padding([.leading, .trailing], 10)
                        }
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @State private var searchText = ""
    @State private var history = HistoryArray
    @ObservedObject var searchResults: SearchEnumeratorWrapper = SearchEnumeratorWrapper()
    
    func forEachSearchResults(arr: some RandomAccessCollection<DatabaseWord>, screenWidth: CGFloat) -> some View {
        ForEach(arr, id: \.self) { name in
            NavigationLink {
                NavigationLazyView(
                    DefinitionView(dbWord: name, screenWidth: screenWidth)
                ).navigationBarTitleDisplayMode(.inline)
            } label: {
                let readings = name.readings.filter({ $0 != name.word })
                Text(name.word + (!readings.isEmpty ? " [" + readings.filter({ $0 != name.word }).joined(separator: ", ") + "]" : ""))
            }.onAppear {
                let last: DatabaseWord = arr.last!
                if last == name {
                    searchResults.addToLazyArray()
                }
            }
        }
    }
    
    var body: some View {
        let searchStringBinding = Binding<String>(get: {
            self.searchText
        }, set: {
            if $0 != self.searchText {
                if $0.isEmpty {
                    searchResults.searchEnumerator = nil
                    searchResults.partialSearch = []
                } else {
                    searchResults.searchEnumerator = CJE_Dictionary.searchText(searchString: $0)
                    if $0.count >= 2 {
                        searchResults.partialSearch = CJE_Dictionary.partialSearch(searchString: $0)
                    } else {
                        searchResults.partialSearch = []
                    }
                }
            }
            self.searchText = $0
        })
        
        GeometryReader { geo in
            NavigationView {
                VStack {
                    List {
                        if !searchResults.lazyArray.isEmpty {
                            forEachSearchResults(arr: searchResults.lazyArray, screenWidth: geo.maxWidth)
                        } else {
                            ForEach(history, id: \.self) { name in
                                NavigationLink {
                                    Text(name)
                                } label: {
                                    Text(name)
                                }
                            }
                        }
                        if !searchResults.partialSearch.isEmpty {
                            Label("Partial Search", systemImage: "magnifyingglass.circle")
                            forEachSearchResults(arr: Array(searchResults.partialSearch), screenWidth: geo.maxWidth)
                        }
                    }.id(searchResults.searchEnumerator?.id ?? UUID())
                }
                .id(searchResults.searchEnumerator?.id ?? UUID())
                .navigationTitle(LocalizedStringKey("dictionary"))
            }
            .searchable(text: searchStringBinding)
            .alert(isPresented: Binding<Bool> (get: {
                ConjugationManager.sharedInstance.error
            }, set: {_ in
            }), error: CSVError.runtimeError("Binary error")) {_ in
                Button(action: {
                    exit(0)
                }, label: {
                    Text("OK")
                })
            } message: { err in
                Text("The app binary resources are invalid.")
            }
        }
    }
}

#Preview {
    ContentView()
}
