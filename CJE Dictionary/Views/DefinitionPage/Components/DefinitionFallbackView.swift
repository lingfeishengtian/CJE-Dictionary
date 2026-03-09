//
//  DefinitionFallbackView.swift
//  CJE Dictionary
//

import SwiftUI

struct DefinitionFallbackView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .textSelection(.enabled)
    }
}
