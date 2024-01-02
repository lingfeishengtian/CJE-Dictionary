//
//  ContentView.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/30/23.
//

import SwiftUI
import RealmSwift

struct ContentView: View {
    @State private var searchText = ""
    @State private var history = HistoryArray
    
    var body: some View {
        NavigationView {
            List {
                if (!searchText.isEmpty) {
                    ForEach(searchResults, id: \.self) { name in
                        NavigationLink {
                            Text(name.spell ?? "")
                        } label: {
                            Text(name.spell ?? "")
                        }
                    }
                } else {
                    ForEach(history, id: \.self) { name in
                        NavigationLink {
                            Text(name)
                        } label: {
                            Text(name)
                        }
                    }
                }
            }
            .id(UUID())
            .navigationTitle(LocalizedStringKey("dictionary"))
        }
        .searchable(text: $searchText)
    }
    
    var searchResults: [Wort] {
        return CJE_Dictionary.searchText(searchString: searchText)
    }
}

#Preview {
    ContentView()
}
