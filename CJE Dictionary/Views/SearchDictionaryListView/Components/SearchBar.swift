//
//  SearchBar.swift
//  CJE Dictionary
//
//  Created by OpenCode on behalf of user.
//

import SwiftUI

/// Lightweight search bar used across search screens. No debounce by default.
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled(true)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct SearchBar_Previews: PreviewProvider {
    struct P: View {
        @State var q = ""
        var body: some View { SearchBar(text: $q) }
    }
    static var previews: some View { P() }
}
