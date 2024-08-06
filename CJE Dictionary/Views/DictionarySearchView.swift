//
//  ContentView.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/30/23.
//

import SwiftUI

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

struct DictionarySearchView: View {
    @State private var searchText = ""
    @ObservedObject var searchResults: SearchEnumeratorWrapper = SearchEnumeratorWrapper()
    
    func makeSearchQuery(searchString: String) {
        if searchString == self.searchText {
            return
        }
        if searchString.isEmpty {
            searchResults.searchEnumerator = nil
            searchResults.partialSearch = []
        } else {
            let timeRn = Date.now
            searchResults.searchEnumerator = CJE_Dictionary.searchText(searchString: convertHanziStringToKanji(str: searchString))
            let tookToRun = (Date.now.timeIntervalSince(timeRn) * 1000 * 1000).rounded() / 1000
            print("\(tookToRun) ms")
            
            if searchString.count >= 2 {
                if searchResults.searchEnumerator?.lazyArray.count ?? 11 <= 10 {
                    searchResults.partialSearch = CJE_Dictionary.partialSearch(searchQuery: searchString)
                }
            } else {
                searchResults.partialSearch = []
            }
        }
    }
    
    var body: some View {
        let searchStringBinding = Binding<String>(get: {
            self.searchText
        }, set: {
            makeSearchQuery(searchString: $0)
            self.searchText = $0
        })
        
        let arraySelected = (searchResults.lazyArray.isEmpty && searchText.isEmpty) ? HistoryArray : searchResults.lazyArray
        
        NavigationStack {
            VStack {
                if HistoryArray.isEmpty && searchResults.lazyArray.isEmpty && searchResults.partialSearch.isEmpty
                {
                    Text("Welcome to CJE Dictionary")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Text("Start searching!")
                        .font(.subheadline)
                        .fontWeight(.light)
                        .multilineTextAlignment(.center)
                } else {
                    List {
                        if searchText.count == 1, let kanjiInfo = getKanjiInfo(for: [searchText]).first {
                            NavigationLink(String(kanjiInfo.kanjiCharacter)) {
                                NavigationLazyView (
                                    KanjiDefinition(kanjiInfo: kanjiInfo)
                                ).navigationBarTitleDisplayMode(.inline)
                            }
                        }
                        ForEach(arraySelected, id: \.self) { name in
                            DefinitionNavigationLink(name: name).onAppear {
                                let last: DatabaseWord = arraySelected.last!
                                if last == name {
                                    searchResults.addToLazyArray()
                                }
                            }
                        }
                        if !searchResults.partialSearch.isEmpty {
                            Label("Partial Search", systemImage: "magnifyingglass.circle")
                            ForEach(searchResults.partialSearch, id: \.self) { name in
                                DefinitionNavigationLink(name: name)
                            }
                        }
                    }.id(searchResults.searchEnumerator?.id ?? UUID())
                }
            }
            .searchable(text: searchStringBinding)
            .navigationTitle(LocalizedStringKey("dictionary"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .autocorrectionDisabled()
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

struct DefinitionNavigationLink: View {
    let name: DatabaseWord
    let labelTxt: String
    
    init(name: DatabaseWord) {
        self.name = name
        
        let readings = name.readings.filter({ $0 != name.word })
        if !readings.isEmpty {
            self.labelTxt = name.word + " [" + readings.filter({ $0 != name.word }).joined(separator: ", ") + "]"
        } else {
            self.labelTxt = name.word
        }
    }
    
    var body: some View {
        NavigationLink(labelTxt) {
            NavigationLazyView(
                DefinitionView(dbWord: name, definitions: lookupWord(word: name).definitions).onAppear {
                    HistoryArray.removeAll(where: { $0.readings == name.readings })
                    HistoryArray.insert(name, at: 0)
                }
            ).navigationBarTitleDisplayMode(.inline)
        }
    }
}

let sampleWord = DatabaseWord(id: 1, dict: DICTIONARY_NAMES.jitendex, word: "為", readingsString: "する|する【∅】|する【為る】|為る", meaning: """
<link rel='stylesheet' href='common.css' type='text/css'><br><link rel='stylesheet' href='jitendex.css' type='text/css'><br><div><div class="headline priority no-furigana"><span class="headword" lang="ja"><span>する</span></span><span class="priority-symbol" title="high priority entry">★</span></div><ul class="sense-groups" data-sense-count="17" data-sense-group-count="6"><li class="sense-group"><span class="part-of-speech-container"><span class="tag part-of-speech-info" data-code="vs-i" title="suru verb - included">suru</span></span><span class="misc-container"><span class="tag misc-info" data-code="uk" title="word usually written using kana alone">kana</span></span><ol class="sense-list"><li class="sense" data-sense-number="1" style="list-style-type: '①';"><ul class="glossary"><li class="gloss">to do</li><li class="gloss">to carry out</li><li class="gloss">to perform</li></ul><div class="extra-info"><div class="example-container"><div class="ex-sent extra-box" data-sentence-key="する" data-source="236605" data-source-type="tat"><div class="ex-sent-ja"><span class="ex-sent-ja-content" lang="ja">「これ<ruby>以<rt>い</rt></ruby><ruby>上<rt>じょう</rt></ruby><ruby>何<rt>なに</rt></ruby>も<ruby>言<rt>い</rt></ruby>うことはありません、いいわけを<span class="ex-sent-ja-keyword">する</span>のはいやですから」と<ruby>彼<rt>かれ</rt></ruby>は<ruby>言<rt>い</rt></ruby>った。</span></div><div class="ex-sent-en"><span class="ex-sent-en-content" lang="en">He said, "I will say nothing more, because I hate making excuses."</span><span class="ex-sent-ja-footnote">[1]</span></div></div></div></div></li><li class="sense" data-sense-number="2" style="list-style-type: '②';"><ul class="glossary"><li class="gloss">to cause to become</li><li class="gloss">to make (into)</li><li class="gloss">to turn (into)</li></ul><div class="extra-info"><div class="example-container"><div class="ex-sent extra-box" data-sentence-key="する" data-source="204729" data-source-type="tat"><div class="ex-sent-ja"><span class="ex-sent-ja-content" lang="ja">それらはあなたを<ruby>暖<rt>あたた</rt></ruby>かく<span class="ex-sent-ja-keyword">する</span>のに<ruby>役<rt>やく</rt></ruby><ruby>立<rt>だ</rt></ruby>つでしょう。</span></div><div class="ex-sent-en"><span class="ex-sent-en-content" lang="en">They will help you to get warm.</span><span class="ex-sent-ja-footnote">[2]</span></div></div></div></div></li><li class="sense" data-sense-number="3" style="list-style-type: '③';"><ul class="glossary"><li class="gloss">to serve as</li><li class="gloss">to act as</li><li class="gloss">to work as</li></ul><div class="extra-info"><div class="example-container"><div class="ex-sent extra-box" data-sentence-key="して" data-source="123813" data-source-type="tat"><div class="ex-sent-ja"><span class="ex-sent-ja-content" lang="ja"><ruby>頭<rt>ず</rt></ruby><ruby>痛<rt>つう</rt></ruby>を<ruby>言<rt>い</rt></ruby>い<ruby>訳<rt>わけ</rt></ruby>に<span class="ex-sent-ja-keyword">して</span>、<ruby>彼<rt>かれ</rt></ruby>は<ruby>早<rt>はや</rt></ruby>く<ruby>帰<rt>かえ</rt></ruby>った。</span></div><div class="ex-sent-en"><span class="ex-sent-en-content" lang="en">He used a headache as an excuse for leaving early.</span><span class="ex-sent-ja-footnote">[3]</span></div></div></div></div></li><li class="sense" data-sense-number="4" style="list-style-type: '④';"><ul class="glossary"><li class="gloss">to wear (clothes, a facial expression, etc.)</li></ul><div class="extra-info"><div class="example-container"><div class="ex-sent extra-box" data-sentence-key="する" data-source="204304" data-source-type="tat"><div class="ex-sent-ja"><span class="ex-sent-ja-content" lang="ja">そんな<ruby>苦<rt>にが</rt></ruby><ruby>虫<rt>むし</rt></ruby>を<ruby>噛<rt>か</rt></ruby>みつぶしたような<ruby>顔<rt>かお</rt></ruby><span class="ex-sent-ja-keyword">する</span>なよ。</span></div><div class="ex-sent-en"><span class="ex-sent-en-content" lang="en">Don't make such a sour face.</span><span class="ex-sent-ja-footnote">[4]</span></div></div></div></div></li><li class="sense" data-sense-number="5" style="list-style-type: '⑤';"><ul class="glossary"><li class="gloss">to judge as being</li><li class="gloss">to view as being</li><li class="gloss">to think of as</li><li class="gloss">to treat as</li><li class="gloss">to use as</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">as 〜にする,〜とする</div></div></div></li><li class="sense" data-sense-number="6" style="list-style-type: '⑥';"><ul class="glossary"><li class="gloss">to decide on</li><li class="gloss">to choose</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">as 〜にする</div></div><div class="example-container"><div class="ex-sent extra-box" data-sentence-key="し" data-source="175788" data-source-type="tat"><div class="ex-sent-ja"><span class="ex-sent-ja-content" lang="ja"><ruby>結<rt>けっ</rt></ruby><ruby>構<rt>こう</rt></ruby>です。それに<span class="ex-sent-ja-keyword">し</span>ましょう。</span></div><div class="ex-sent-en"><span class="ex-sent-en-content" lang="en">All right. I'll take it.</span><span class="ex-sent-ja-footnote">[5]</span></div></div></div></div></li></ol></li><li class="sense-group"><span class="part-of-speech-container"><span class="tag part-of-speech-info" data-code="vs-i" title="suru verb - included">suru</span><span class="tag part-of-speech-info" data-code="vi" title="intransitive verb">intransitive</span></span><span class="misc-container"><span class="tag misc-info" data-code="uk" title="word usually written using kana alone">kana</span></span><ol class="sense-list"><li class="sense" data-sense-number="7" style="list-style-type: '⑦';"><ul class="glossary"><li class="gloss">to be sensed (of a smell, noise, etc.)</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">as 〜がする</div></div><div class="example-container"><div class="ex-sent extra-box" data-sentence-key="する" data-source="449136" data-source-type="tat"><div class="ex-sent-ja"><span class="ex-sent-ja-content" lang="ja">このスープはいやなにおいが<span class="ex-sent-ja-keyword">する</span>。<ruby>腐<rt>くさ</rt></ruby>っているでしょう？</span></div><div class="ex-sent-en"><span class="ex-sent-en-content" lang="en">This soup smells horrible. Do you think it's gone off?</span><span class="ex-sent-ja-footnote">[6]</span></div></div></div></div></li><li class="sense" data-sense-number="8" style="list-style-type: '⑧';"><ul class="glossary"><li class="gloss">to be (in a state, condition, etc.)</li></ul></li><li class="sense" data-sense-number="9" style="list-style-type: '⑨';"><ul class="glossary"><li class="gloss">to be worth</li><li class="gloss">to cost</li></ul></li><li class="sense" data-sense-number="10" style="list-style-type: '⑩';"><ul class="glossary"><li class="gloss">to pass (of time)</li><li class="gloss">to elapse</li></ul><div class="extra-info"><div class="example-container"><div class="ex-sent extra-box" data-sentence-key="したら" data-source="106699" data-source-type="tat"><div class="ex-sent-ja"><span class="ex-sent-ja-content" lang="ja"><ruby>彼<rt>かれ</rt></ruby>は<ruby>三<rt>みっ</rt></ruby><ruby>日<rt>か</rt></ruby><span class="ex-sent-ja-keyword">したら</span><ruby>出<rt>しゅっ</rt></ruby><ruby>発<rt>ぱつ</rt></ruby>する。</span></div><div class="ex-sent-en"><span class="ex-sent-en-content" lang="en">He is leaving in three days.</span><span class="ex-sent-ja-footnote">[7]</span></div></div></div></div></li></ol></li><li class="sense-group"><span class="part-of-speech-container"><span class="tag part-of-speech-info" data-code="vs-i" title="suru verb - included">suru</span><span class="tag part-of-speech-info" data-code="vt" title="transitive verb">transitive</span></span><span class="misc-container"><span class="tag misc-info" data-code="uk" title="word usually written using kana alone">kana</span></span><ol class="sense-list"><li class="sense" data-sense-number="11" style="list-style-type: '⑪';"><ul class="glossary"><li class="gloss">to place, or raise, person A to a post or status B</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">as AをBにする</div></div></div></li><li class="sense" data-sense-number="12" style="list-style-type: '⑫';"><ul class="glossary"><li class="gloss">to transform A to B</li><li class="gloss">to make A into B</li><li class="gloss">to exchange A for B</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">as AをBにする</div></div></div></li><li class="sense" data-sense-number="13" style="list-style-type: '⑬';"><ul class="glossary"><li class="gloss">to make use of A for B</li><li class="gloss">to view A as B</li><li class="gloss">to handle A as if it were B</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">as AをBにする</div></div></div></li><li class="sense" data-sense-number="14" style="list-style-type: '⑭';"><ul class="glossary"><li class="gloss">to feel A about B</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">as AをBにする</div></div></div></li></ol></li><li class="sense-group"><span class="part-of-speech-container"><span class="tag part-of-speech-info" data-code="suf" title="suffix">suffix</span><span class="tag part-of-speech-info" data-code="vs-i" title="suru verb - included">suru</span></span><span class="misc-container"><span class="tag misc-info" data-code="uk" title="word usually written using kana alone">kana</span></span><ol class="sense-list"><li class="sense" data-sense-number="15" style="list-style-type: '⑮';"><ul class="glossary"><li class="gloss">verbalizing suffix (applies to nouns noted in this dictionary with the part of speech "vs")</li></ul></li></ol></li><li class="sense-group"><span class="part-of-speech-container"><span class="tag part-of-speech-info" data-code="aux-v" title="auxiliary verb">aux-verb</span><span class="tag part-of-speech-info" data-code="vs-i" title="suru verb - included">suru</span></span><span class="misc-container"><span class="tag misc-info" data-code="uk" title="word usually written using kana alone">kana</span></span><ol class="sense-list"><li class="sense" data-sense-number="16" style="list-style-type: '⑯';"><ul class="glossary"><li class="gloss">creates a humble verb (after a noun prefixed with "o" or "go")</li></ul><div class="extra-info"><div class="xref-container"><div class="xref extra-box"><div class="xref-content"><span class="reference-label" lang="en">See:</span><a data-target-id="1001720" href="bword://おねがいします【お願いします】" lang="ja"><span class="xref-furigana">お<ruby>願<rt>ねが</rt></ruby>いします</span></a></div><div class="xref-glossary">please</div></div><div class="xref extra-box"><div class="xref-content"><span class="reference-label" lang="en">See:</span><a data-target-id="1270190" href="bword://ご【御】" lang="ja"><span class="xref-furigana"><ruby>御<rt>ご</rt></ruby></span></a></div><div class="xref-glossary">① honorific/polite/humble prefix</div></div></div></div></li><li class="sense" data-sense-number="17" style="list-style-type: '⑰';"><ul class="glossary"><li class="gloss">to be just about to</li><li class="gloss">to be just starting to</li><li class="gloss">to try to</li><li class="gloss">to attempt to</li></ul><div class="extra-info"><div class="sense-note-container extra-box"><div class="sense-note-label extra-label">Note</div><div class="sense-note-content extra-content">as 〜うとする,〜ようとする</div></div><div class="xref-container"><div class="xref extra-box"><div class="xref-content"><span class="reference-label" lang="en">See:</span><a data-target-id="2136890" href="bword://とする【∅】" lang="ja">とする</a></div><div class="xref-glossary">① to try to ...; to be about to do ...</div></div></div></div></li></ol></li><li class="forms"><span class="tag forms-label" title="spelling and reading variants">forms</span><table><tr class="forms-header-row"><th/><th><span class="form-special" title="no associated kanji forms">∅</span></th><th>為る</th></tr><tr class="forms-body-row"><th>する</th><td><span class="circle form-pri" title="high priority form">優</span></td><td><span class="circle form-rare" title="rarely used form">稀</span></td></tr></table></li></ul><div class="entry-footnotes"><a href="https://www.edrdg.org/jmwsgi/entr.py?svc=jmdict&amp;q=1157170">JMdict</a> | Tatoeba <a href="https://tatoeba.org/en/sentences/show/236605">[1]</a><a href="https://tatoeba.org/en/sentences/show/204729">[2]</a><a href="https://tatoeba.org/en/sentences/show/123813">[3]</a><a href="https://tatoeba.org/en/sentences/show/204304">[4]</a><a href="https://tatoeba.org/en/sentences/show/175788">[5]</a><a href="https://tatoeba.org/en/sentences/show/449136">[6]</a><a href="https://tatoeba.org/en/sentences/show/106699">[7]</a></div></div>
""")

#Preview {
    let view = DictionarySearchView()
    view.searchResults.searchEnumerator = SearchResultsEnumerator()
    view.searchResults.searchEnumerator?.lazyArray = [sampleWord]
    view.searchResults.partialSearch = [sampleWord]
    return view
}
