//
//  DefinitionPage.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/1/26.
//

import SwiftUI

struct DefinitionPage: View {
    let key: SearchResultKey

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(key.keyText)
                .font(.largeTitle)
                .bold()

            Text("Dictionary: \(key.dictionaryName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let readings = key.readings, !readings.isEmpty {
                Text("Readings: " + readings.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }

            Text("ID: \(key.id)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle(key.keyText)
    }
}
