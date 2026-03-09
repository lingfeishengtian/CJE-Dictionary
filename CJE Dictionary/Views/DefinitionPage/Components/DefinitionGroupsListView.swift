//
//  DefinitionGroupsListView.swift
//  CJE Dictionary
//

import SwiftUI

struct DefinitionGroupsListView: View {
    let definitionGroups: [DefinitionGroup]
    let screenWidth: CGFloat

    var body: some View {
        ForEach(definitionGroups) { group in
            DefinitionGroupSectionView(group: group, screenWidth: screenWidth)
            Divider()
        }
    }
}
