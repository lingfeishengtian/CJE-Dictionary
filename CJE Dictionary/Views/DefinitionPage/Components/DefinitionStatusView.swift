//
//  DefinitionStatusView.swift
//  CJE Dictionary
//

import SwiftUI

struct DefinitionStatusView: View {
    let isLoading: Bool
    let errorMessage: String

    var body: some View {
        Group {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
    }
}
