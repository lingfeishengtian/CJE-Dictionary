//
//  DefinitionGroupSectionView.swift
//  CJE Dictionary
//

import SwiftUI

struct DefinitionGroupSectionView: View {
    let group: DefinitionGroup
    let screenWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !group.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(group.tags) { tag in
                            Text(tag.longName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.gray.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            ForEach(Array(group.definitions.enumerated()), id: \.offset) { index, definition in
                DefinitionItemView(index: index, definition: definition, screenWidth: screenWidth)
            }
        }
    }
}
