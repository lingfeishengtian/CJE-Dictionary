//
//  HTMLParser.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 1/6/24.
//

import Foundation

struct ExampleSentence: Identifiable, Codable {
    var id: String {
        (language?.rawValue ?? "") + attributedString.description
    }
    let language: Language?
    let attributedString: AttributedString

    private enum CodingKeys: String, CodingKey { case language = "language", attributedString = "sentence" }

    init(language: Language?, attributedString: AttributedString) {
        self.language = language
        self.attributedString = attributedString
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.language = try container.decodeIfPresent(Language.self, forKey: .language)
        let markdownString = try container.decode(String.self, forKey: .attributedString)
        self.attributedString = try AttributedString(
            markdown: markdownString,
            including: \.cje,
            options: .init(allowsExtendedAttributes: true)
        )
    }
}

struct DefinitionGroup: Identifiable, Codable {
    let tags: [Tag]
    let definitions: [Definition]
    var id: String {
        var d = ""
        for definition in definitions {
            d.append(definition.id)
        }
        if d.isEmpty {
            return "emptyDefinitions"
        }
        return d
    }
}

struct Tag: Identifiable, Hashable, Codable {
    let shortName: String
    let longName: String
    var id: String {
        shortName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(shortName)
    }
}

struct Definition: Codable {
    var id: String {
        definition
    }
    let definition: String
    let exampleSentences: [ExampleSentence]
}
