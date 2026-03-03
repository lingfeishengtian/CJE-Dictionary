//
//  Noresults.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/1/26.
//

import SwiftUI


struct NoResults: View {
    var query: String
    
    var body: some View {
            Spacer()
            Text(query.isEmpty ? "Start typing to search" : "No results")
                .foregroundStyle(.secondary)
            Spacer()
    }
}
