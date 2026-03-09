//
//  SearchResultsView.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/1/26.
//

import SwiftUI

// Displays search results and handles navigation to definitions.
struct SearchResultsView: View {
    @ObservedObject var streamManager: SearchStreamManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(streamManager.results.enumerated()), id: \.element) { index, key in
                    NavigationLink(destination: DefinitionPage(key: key, dictionary: streamManager.dictionary(for: key))) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(key.keyText)
                                    .font(.body)
                                if let readings = key.readings, !readings.isEmpty {
                                    Text(readings.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(key.dictionaryName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buttonStyle(.plain)
                    .onAppear {
                        // load next page when last cell appears
                        if index == streamManager.results.count - 1 {
                            streamManager.loadMore()
                        }
                    }

                    Divider()
                }
            }
        }
    }
}
