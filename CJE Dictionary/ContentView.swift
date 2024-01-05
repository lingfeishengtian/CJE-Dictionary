//
//  ContentView.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/30/23.
//

import SwiftUI
import RealmSwift
import WebKit
import struct SQLite.Row

struct WebView: UIViewRepresentable {
    let name: DatabaseWord
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
 
    func updateUIView(_ webView: WKWebView, context: Context) {
        Task {
            var str = ""
            let def = lookupWord(word: name)
            for def in def.definitions {
                str.append(def.1)
            }
            
            webView.loadHTMLString(str, baseURL: nil)
        }
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


struct ContentView: View {
    @State private var searchText = ""
    @State private var history = HistoryArray
    @ObservedObject var searchResults: SearchEnumeratorWrapper = SearchEnumeratorWrapper()
    
    func forEachSearchResults(arr: some RandomAccessCollection<DatabaseWord>) -> some View {
        ForEach(arr, id: \.self) { name in
            NavigationLink {
                NavigationLazyView(
                    WebView(name: name)
                )
            } label: {
                Text(name.word + " [" + name.readings.filter({ $0 != name.word }).joined(separator: ", ") + "]")
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
                } else {
                    searchResults.searchEnumerator = CJE_Dictionary.searchText(searchString: $0)
                    if $0.count >= 2 {
                        searchResults.partialSearch = CJE_Dictionary.partialSearch(searchString: $0)
                    }
                }
            }
            self.searchText = $0
        })
        NavigationView {
            VStack {
                List {
                    if !searchResults.lazyArray.isEmpty {
                        forEachSearchResults(arr: searchResults.lazyArray)
                    } else {
                        ForEach(history, id: \.self) { name in
                            NavigationLink {
                                Text(name)
                            } label: {
                                Text(name)
                            }
                        }
                    }
                }.id(searchResults.searchEnumerator?.id ?? UUID())
                List {
                    if !searchResults.partialSearch.isEmpty {
                        Text("Partial Search")
                        forEachSearchResults(arr: Array(searchResults.partialSearch))
                    }
                }
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
    
//    var searchResultsQuery: AnySequence<Row> {
//        print(Date.now.timeIntervalSince1970)
//        let d = CJE_Dictionary.searchText(searchString: searchText)
//        print(Date.now.timeIntervalSince1970)
//        return AnySequence(d)
//    }
}

#Preview {
    ContentView()
}
