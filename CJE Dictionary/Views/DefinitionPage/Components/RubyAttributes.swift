//
//  RubyAttributes.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/6/26.
//

import Foundation

enum CTRubyAnnotationAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    static let name = "CTRubyAnnotation"
    typealias Value = String
}

extension AttributeScopes {
    struct CJEAttributes: AttributeScope {
        let ctRubyAnnotation: CTRubyAnnotationAttribute
    }

    var cje: CJEAttributes.Type { CJEAttributes.self }
}
