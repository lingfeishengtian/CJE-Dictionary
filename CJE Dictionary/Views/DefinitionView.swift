//
//  DefinitionView.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 8/3/24.
//

import SwiftUI
import Flow

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
    @State private var conjugations: [ConjugatedVerb]
    @State var selectedLanguage: Language
    @Environment(\.colorScheme) var colorScheme
    private let kanjiInfos: [KanjiInfo]
    @StateObject var navigationDelegate: ParserNavigationDelegate
    
    init(dbWord: DatabaseWord) {
        self.dbWord = dbWord
        let parserObject = ParserNavigationDelegate(databaseWord: dbWord)
        _navigationDelegate = StateObject(wrappedValue: parserObject)
        self.selectedLanguage = parserObject.getResultingLanguages().first!
        self.conjugations = []
        self.kanjiInfos = getKanjiInfo(for: dbWord.readings)
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
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(Language.allCases) { lang in
                                if navigationDelegate.getResultingLanguages().contains(lang) {
                                    Text(LocalizedStringKey(lang.rawValue)).tag(lang)
                                }
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding([.leading, .trailing], 20)
                        .onChange(of: selectedLanguage) { a, b in
                            self.navigationDelegate.errorMessage = ""
                            if !self.navigationDelegate.doesLanguageExistInCache(lang: b) {
                                navigationDelegate.initiateHTMLParse(language: b)
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
                        ForEach(self.navigationDelegate.getDefinitionGroupInCache(for: selectedLanguage)) { definitionGroup in
                            TagList(tags: definitionGroup.tags)
                                .padding([.leading, .trailing], 20)
                            if definitionGroup.tags.isEmpty {
                                Spacer(minLength: 7)
                            }
                            ForEach(0..<definitionGroup.definitions.count, id: \.self) { index in
                                let definition = definitionGroup.definitions[index]
                                Text("\(index + 1). \(definition.definition)")
                                    .padding([.bottom], 5)
                                    .contentMargins(10)
                                    .padding([.leading, .trailing], 20)
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

struct FlowLayout: Layout {
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for size in sizes {
            if lineWidth + size.width > proposal.width ?? 0 {
                totalHeight += lineHeight
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width
                lineHeight = max(lineHeight, size.height)
            }
            
            totalWidth = max(totalWidth, lineWidth)
        }
        
        totalHeight += lineHeight
        
        return .init(width: totalWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var lineX = bounds.minX
        var lineY = bounds.minY
        var lineHeight: CGFloat = 0
        
        for index in subviews.indices {
            if lineX + sizes[index].width > (proposal.width ?? 0) {
                lineY += lineHeight
                lineHeight = 0
                lineX = bounds.minX
            }
            
            subviews[index].place(
                at: .init(
                    x: lineX + sizes[index].width / 2,
                    y: lineY + sizes[index].height / 2
                ),
                anchor: .center,
                proposal: ProposedViewSize(sizes[index])
            )
            
            lineHeight = max(lineHeight, sizes[index].height)
            lineX += sizes[index].width
        }
    }
}

struct TagList: View {
    @Environment(\.colorScheme) var colorScheme
    let tags: [Tag]
    var body: some View {
        HFlow(spacing: 5) {
            ForEach(tags) { tag in
                VStack {
                    Text(tag.longName)
                        .font(Font.caption2)
                        .padding(7)
                        .lineLimit(nil)
                }
                .background(colorScheme == .dark ? Color(.gray).brightness(-0.3) : Color(.gray).brightness(0.3))
                .clipShape(.rect(cornerRadius: 13))
            }
        }
    }
}
