//
//  DefinitionHeaderView.swift
//  CJE Dictionary
//

import SwiftUI

struct DefinitionHeaderView: View {
    let key: SearchResultKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let readings = key.readings, !readings.isEmpty {
                Text(readings.joined(separator: " • "))
                    .foregroundStyle(.secondary)
            }

            Text("Dictionary: \(key.dictionaryName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
