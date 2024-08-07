//
//  DefinitionView.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 8/3/24.
//

import SwiftUI

fileprivate struct ExampleSentenceTextView: View {
    let attributedString: AttributedString
    let screenWidth: CGFloat
    let language: Language?
    
    init(attributedString: AttributedString, screenWidth: CGFloat, language: Language?) {
        var flagEmoji: String {
            switch language {
            case .CN:
                "🇨🇳"
            case .EN:
                "🇺🇸"
            case .JP:
                "🇯🇵"
            default:
                ""
            }
        }
        self.language = language
        var beginning = AttributedString(stringLiteral: flagEmoji + " ")
        beginning.append(attributedString)
        beginning.mergeAttributes(try! AttributeContainer([.font: UIFont(name: language == .CN ? "STSong" : "HiraMinProN-W3", size: 15)!], including: \.uiKit))
        self.attributedString = beginning
        self.screenWidth = screenWidth
    }
    
    var body: some View {
        RubyDisplay(attributedString: attributedString, screenWidth: screenWidth).padding([.bottom], language == .CN ? 10 : 0)
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

struct DefinitionView: View {
    let dbWord: DatabaseWord
    private let queue: [LanguageToLanguage: DatabaseWord]
    let cached: [LanguageToLanguage: [DefinitionGroup]]
    @State private var conjugations: [ConjugatedVerb]
    @State var selectedLangugae: Language
    @Environment(\.colorScheme) var colorScheme
    private let kanjiInfos: [KanjiInfo]
    @StateObject var navigationDelegate = ParserNavigationDelegate()
    
    init(dbWord: DatabaseWord) {
        self.dbWord = dbWord
        let lookupResults = lookupWord(word: dbWord)
        self.cached = lookupResults.definitions
        self.queue = lookupResults.queuedDefinitions
        
        var tmpLang = queue[LanguageToLanguage(searchLanguage: .JP, resultsLanguage: .EN)] != nil ? .EN : queue.first?.key.resultsLanguage
        if tmpLang == nil {
            tmpLang = lookupResults.definitions.first!.key.resultsLanguage
        }
        self.selectedLangugae = tmpLang!
        
        self.conjugations = []
        self.kanjiInfos = getKanjiInfo(for: dbWord.readings)
    }
    
    func locateSelectedLanguageInQueue(language: Language? = nil) -> DatabaseWord? {
        return queue.first(where: { $0.key.resultsLanguage == (language ?? selectedLangugae) })?.value
    }
    
    var body: some View {
        // TODO: Move conjugations to NavigationDelegate
        if (conjugations.isEmpty) {
            var conj: [ConjugatedVerb] = []
            let enDefs = self.navigationDelegate.getDefinitionGroupInCache(for: .EN)
            var tagSet: Set<Tag> = []
            enDefs.forEach({ tagSet.formUnion($0.tags) })
            
            for tag in tagSet {
                let c = ConjugationManager.sharedInstance.conjugate(dbWord.word, verbType: tag.shortName)
                if !c.isEmpty {
                    conj = c
                }
            }
            DispatchQueue.main.async { self.conjugations = conj }
        }
        return GeometryReader { geo in
            ScrollView {
                VStack(alignment: (navigationDelegate.showLoading) ? .center : .leading) {
                    RubyDisplay(attributedString: dbWord.generateAttributedStringTitle(), screenWidth: geo.maxWidth)
                        .padding([.top], 10)
                    if conjugations.count > 1 {
                        ConjugationViewer(conjugatedVerbs: conjugations)
                            .frame(height: 38, alignment: .center)
                            .padding([.leading, .trailing], 35)
                            .padding([.bottom])
                    }
                    if navigationDelegate.showLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                        Spacer()
                    } else {
                        Picker("Language", selection: $selectedLangugae) {
                            ForEach(Language.allCases) { lang in
                                if self.navigationDelegate.doesLanguageExistInCache(lang: lang) || locateSelectedLanguageInQueue(language: lang) != nil {
                                    Text(LocalizedStringKey(lang.rawValue)).tag(lang)
                                }
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding([.leading, .trailing], 20)
                        .onChange(of: selectedLangugae) { a, b in
                            self.navigationDelegate.errorMessage = ""
                            if !self.navigationDelegate.doesLanguageExistInCache(lang: b) {
                                navigationDelegate.initiateHTMLParse(dbWord: locateSelectedLanguageInQueue()!)
                            }
                        }
                        if navigationDelegate.errorMessage.count > 0 {
                            HStack {
                                Spacer()
                                Text(navigationDelegate.errorMessage)
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                        }
                        ForEach(self.navigationDelegate.getDefinitionGroupInCache(for: selectedLangugae)) { definitionGroup in
                            HStack {
                                ForEach(definitionGroup.tags) { tag in
                                    Text(tag.longName)
                                        .font(Font.caption2)
                                        .padding(7)
                                        .background(colorScheme == .dark ? Color(.gray).brightness(-0.3) : Color(.gray).brightness(0.3))
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
                                    ExampleSentenceTextView(attributedString: elem.attributedString, screenWidth: geo.maxWidth, language: elem.language)
                                        .padding([.leading, .trailing], 10)
                                }
                            }
                        }
                        if kanjiInfos.count > 0 {
                            Text (String(localized: "Kanji Information"))
                                .font(.headline)
                                .padding([.trailing, .leading], 20)
                            ForEach(kanjiInfos) { kanjiInfo in
                                KanjiNavigationListElement(kanjiInfo: kanjiInfo).padding([.trailing, .leading], 30)
                            }
                        }
                    }
                }
            }
        }.onAppear() {
            self.navigationDelegate.cachedDefinitions = cached
            let getDictWord = locateSelectedLanguageInQueue()
            if getDictWord != nil {
                navigationDelegate.initiateHTMLParse(dbWord: getDictWord!)
            }
        }
    }
}

extension GeometryProxy {
    var maxWidth: CGFloat {
        size.width - safeAreaInsets.leading - safeAreaInsets.trailing
    }
}

struct KanjiNavigationListElement: View {
    @Environment(\.colorScheme) var colorScheme
    let kanjiInfo: KanjiInfo
    
    var body: some View {
        NavigationLink(destination: {
            KanjiDefinition(kanjiInfo: kanjiInfo)
        }, label: {
            HStack {
                Text(String(kanjiInfo.kanjiCharacter))
                    .font(Font.custom("HiraMinProN-W3", size: 30))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                Divider().padding([.leading, .trailing], 10)
                Text(kanjiInfo.meaning.joined(separator: ", "))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .font(Font.custom("HiraMinProN-W3", size: 15))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                Spacer()
                Image(systemName: "arrow.forward")
                    .fontWeight(.medium)
                    .foregroundStyle(
                        .gray
                    )
                    .font(.caption2)
            }
        })
    }
}
