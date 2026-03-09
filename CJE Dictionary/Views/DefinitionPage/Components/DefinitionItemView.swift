//
//  DefinitionItemView.swift
//  CJE Dictionary
//

import SwiftUI
import UIKit

struct DefinitionItemView: View {
    let index: Int
    let definition: Definition
    let screenWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(index + 1). \(definition.definition)")
                .font(.body)

            ForEach(definition.exampleSentences) { sentence in
                HStack(alignment: .top, spacing: 4) {
                    Text(FlagEmojiProvider.flagEmoji(for: sentence.language?.localeCode))
                        .font(.body)

                    RubyDisplay(
                        attributedString: sentence.attributedString,
                        screenWidth: screenWidth,
                        textColor: .secondaryLabel
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .textSelection(.enabled)
    }
}
