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

    init(attributedString: AttributedString, screenWidth: CGFloat, language: Language?) {
        let fontFamilyNames = UIFont.familyNames
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
        var beginning = AttributedString(stringLiteral: flagEmoji + " ")
        beginning.append(attributedString)
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

struct DefinitionView: View {
    let dbWord: DatabaseWord
    private let wordLookup: [(LanguageToLanguage, [DefinitionGroup])]
    private let conjugations: [ConjugatedVerb]
    @State var selectedLangugae: Language
    @Environment(\.colorScheme) var colorScheme
    private let kanjiInfo: [KanjiInfo]
    
    init(dbWord: DatabaseWord, definitions: [(LanguageToLanguage, [DefinitionGroup])]) {
        self.dbWord = dbWord
        self.wordLookup = definitions
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
        self.kanjiInfo = getKanjiInfo(for: dbWord.readings)
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading) {
                    RubyDisplay(attributedString: dbWord.generateAttributedStringTitle(), screenWidth: geo.maxWidth)
                        .padding([.top], 10)
                    if conjugations.count > 1 {
                        ConjugationViewer(conjugatedVerbs: conjugations)
                            .frame(height: 38, alignment: .center)
                            .padding([.leading, .trailing], 35)
                            .padding([.bottom])
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
                    List{
//                        ForEach(kanjiInfo) { kanji in
//                            
//                        }
                        // TODO: Kanji section
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



#Preview {
    DefinitionView(dbWord: sampleWord, definitions: [((Language.JP, Language.EN), sampleWord.parseDefinitionHTML()), ((Language.JP, Language.CN), sampleWord.parseDefinitionHTML(otherHTML: """
<link rel='stylesheet' href='common.css' type='text/css'><br><link rel='stylesheet' href='jitendex.css' type='text/css'><br><div><div class="headline priority"><span class="headword" lang="ja"><span><ruby>何<rt>なに</rt></ruby></span></span><span class="priority-symbol" title="high priority entry">★</span></div><ul class="sense-groups" data-sense-count="8" data-sense-group-count="6"><li class="pronunciation"><span class="tag pronunciation-label" title="pronunciation audio">pronunciation</span><ul class="audio-list"><li class="audio"><a href="sound://kanji_alive_audio/07175-1.opus"><span class="play-button">▶</span></a>なに</li></ul></li><li class="sense-group"><span class="part-of-speech-container"><span class="tag part-of-speech-info" data-code="pn" title="pronoun">pronoun</span></span><ol class="sense-list"><li class="sense" data-sense-number="1" style="list-style-type: '①';"><ul class="glossary"><li class="gloss">what</li></ul><div class="extra-info"><div class="example-container"><div class="ex-sent extra-box" data-sentence-key="何" data-source="172752" data-source-type="tat"><div class="ex-sent-ja"><span class="ex-sent-ja-content" lang="ja"><ruby>今<rt>いま</rt></ruby>のアナウンスは<span class="ex-sent-ja-keyword">何</span>だったのですか。</span></div><div class="ex-sent-en"><span class="ex-sent-en-content" lang="en">What did the announcement just say?</span><span class="ex-sent-ja-footnote">[1]</span></div></div></div></div></li><li class="sense" data-sense-number="2" style="list-style-type: '②';"><ul class="glossary"><li class="gloss">you-know-what</li><li class="gloss">that thing</li></ul></li><li class="sense" data-sense-number="3" style="list-style-type: '③';"><ul class="glossary"><li class="gloss">whatsit</li><li class="gloss">whachamacallit</li><li class="gloss">what's-his-name</li><li class="gloss">what's-her-name</li></ul></li></ol></li><li class="sense-group"><span class="part-of-speech-container"><span class="tag part-of-speech-info" data-code="n" title="noun (common) (futsuumeishi)">noun</span></span><span class="misc-container"><span class="tag misc-info" data-code="col" title="colloquial">colloquial</span><span class="tag misc-info" data-code="uk" title="word usually written using kana alone">kana</span></span><ol class="sense-list"><li class="sense" data-sense-number="4" style="list-style-type: '④';"><ul class="glossary"><li class="gloss">penis</li><li class="gloss">(one's) thing</li><li class="gloss">dick</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">esp. ナニ</div></div><div class="example-container"><div class="ex-sent extra-box" data-sentence-key="ナニ" data-source="77004" data-source-type="tat"><div class="ex-sent-ja"><span class="ex-sent-ja-content" lang="ja">「や、それほどでも。せいぜい、大きさ比べたり、わい談するくらいだし」「大きさって何の？」「<span class="ex-sent-ja-keyword">ナニ</span>の」</span></div><div class="ex-sent-en"><span class="ex-sent-en-content" lang="en">"No, not so much. At most comparing sizes, telling dirty stories." "Sizes of what?" "Of 'that'."</span><span class="ex-sent-ja-footnote">[2]</span></div></div></div></div></li></ol></li><li class="sense-group"><span class="part-of-speech-container"><span class="tag part-of-speech-info" data-code="adv" title="adverb (fukushi)">adverb</span></span><ol class="sense-list"><li class="sense" data-sense-number="5" style="list-style-type: '⑤';"><ul class="glossary"><li class="gloss">(not) at all</li><li class="gloss">(not) in the slightest</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">with neg. sentence</div></div></div></li></ol></li><li class="sense-group"><span class="part-of-speech-container"><span class="tag part-of-speech-info" data-code="int" title="interjection (kandoushi)">interjection</span></span><ol class="sense-list"><li class="sense" data-sense-number="6" style="list-style-type: '⑥';"><ul class="glossary"><li class="gloss">what?</li><li class="gloss">huh?</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">indicates surprise</div></div><div class="example-container"><div class="ex-sent extra-box" data-sentence-key="なに" data-source="75472" data-source-type="tat"><div class="ex-sent-ja"><span class="ex-sent-ja-content" lang="ja"><span class="ex-sent-ja-keyword">なに</span>よ！<ruby>出<rt>で</rt></ruby><ruby>来<rt>き</rt></ruby>ないの？この<ruby>度<rt>ど</rt></ruby><ruby>胸<rt>きょう</rt></ruby>なし！<ruby>腰<rt>こし</rt></ruby><ruby>抜<rt>ぬ</rt></ruby>けッ！</span></div><div class="ex-sent-en"><span class="ex-sent-en-content" lang="en">What? You can't do it? You coward! Chicken!</span><span class="ex-sent-ja-footnote">[3]</span></div></div></div></div></li><li class="sense" data-sense-number="7" style="list-style-type: '⑦';"><ul class="glossary"><li class="gloss">hey!</li><li class="gloss">come on!</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">indicates anger or irritability</div></div></div></li><li class="sense" data-sense-number="8" style="list-style-type: '⑧';"><ul class="glossary"><li class="gloss">oh, no (it's fine)</li><li class="gloss">why (it's nothing)</li><li class="gloss">oh (certainly not)</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">used to dismiss someone's worries, concerns, etc.</div></div></div></li></ol></li><li class="forms"><span class="tag forms-label" title="spelling and reading variants">other forms</span><ul><li>何</li><li>ナニ</li></ul></li></ul><div class="entry-footnotes"><a href="https://www.edrdg.org/jmwsgi/entr.py?svc=jmdict&amp;q=1577100">JMdict</a> | Tatoeba <a href="https://tatoeba.org/en/sentences/show/172752">[1]</a><a href="https://tatoeba.org/en/sentences/show/77004">[2]</a><a href="https://tatoeba.org/en/sentences/show/75472">[3]</a></div></div>
"""))])
}
