//
//  HTMLParser.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 1/6/24.
//

import Foundation
import SwiftSoup
import RubyAttribute
import CoreText
import UIKit

struct DefinitionEntry {
    
}

struct ExampleSentence: Identifiable {
    let id = UUID()
    let language: Language
    let attributedString: AttributedString
}

struct DefinitionGroup: Identifiable {
    let id = UUID()
    let tags: [Tag]
    let definitions: [Definition]
}

struct Tag : Identifiable, Hashable {
    let shortName: String
    let longName: String
    var id: String {
        shortName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(shortName)
    }
}

struct Definition : Identifiable {
    let id = UUID()
    let definition: String
    let exampleSentences: [ExampleSentence]
}

fileprivate func attemptTwoSelectors(doc: SwiftSoup.Document, selectorA: String, selectorB: String) throws -> Elements {
    let optionA = try doc.select(selectorA)
    let optionB = try doc.select(selectorB)
    
    if (optionA.isEmpty()) {
        return optionB
    }
    return optionA
}

fileprivate func generateFuriganaFor(word: String, furigana: String) throws -> AttributedString {
    //try AttributedString(markdown: "^[\((elementNode.getChildNodes().first as! TextNode).text())](CTRubyAnnotation: '\(try elementNode.select("rt").first()?.text() ?? "")')", including: \.coreText, options: .init(allowsExtendedAttributes: true))
    try AttributedString(markdown: "^[\(word)](CTRubyAnnotation: '\(furigana)')", including: \.coreText, options: .init(allowsExtendedAttributes: true))
}

extension DatabaseWord {
    func generateAttributedStringTitle() -> AttributedString {
        var wordAttributedString = AttributedString(word)
        // wordAttributedString.font = .custom("HiraMinProN-W3", size: 45)
        wordAttributedString.setAttributes(try! AttributeContainer([.font: UIFont(name: "HiraMinProN-W3", size: 25)!], including: \.uiKit))
        var pronounciations = AttributedString("【\(readings.filter({ $0 != word }).joined(separator: ", "))】")
        pronounciations.setAttributes(try! AttributeContainer([.font: UIFont(name: "HiraMinProN-W3", size: 15)!], including: \.uiKit))
        // pronounciations.font = .custom("HiraMinProN-W3", size: 15)
        if readings.count > 1 {
            wordAttributedString.append(pronounciations)
        }
        return wordAttributedString
    }
    
    func parseDefinitionHTML(otherHTML: String? = nil) -> [DefinitionGroup] {
        let html = otherHTML ?? meaning
        var definitionGroupArrays: [DefinitionGroup] = []
        do {
            let doc = try SwiftSoup.parse(html)
            
            let pronounciationElements = try attemptTwoSelectors(doc: doc, selectorA: ".pronunciation-text", selectorB: ".pinyin_h")
            var pronounciationText = try pronounciationElements.text(trimAndNormaliseWhitespace: true)
            let definitionsAndReibun = try attemptTwoSelectors(doc: doc, selectorA: ".sense-group", selectorB: "[data-orgtag]")
            let termElems = try attemptTwoSelectors(doc: doc, selectorA: ".headline ruby, .headline .kanji-form-furigana", selectorB: "[data-orgtag=\"subheadword\"]")
            var term = ""
            
            let shouldAddPronounciation = pronounciationText.isEmpty
            for res in termElems {
                if (res.hasAttr("data-orgtag")) {
                    term += try res.text()
                } else {
                    term += res.textNodes().first?.text() ?? ""
                    if (shouldAddPronounciation) {
                        pronounciationText += try res.select("rt").text()
                    }
                }
            }
            
            var shogakuDefArray: [Definition] = []
            var currDef: String?
            var shogakuExampleSentenceArray: [ExampleSentence] = []
            
            for elem in definitionsAndReibun {
                let partOfSpeechs = try elem.select(".tag.part-of-speech-info")
                let senses = try elem.select(".sense")
                
                // TODO: 参见
                if (senses.isEmpty()) {
                    // TODO: glossary and reibun pass as html
                    if (try elem.attr("data-orgtag") == "meaning") {
                        //print("Definition: \(try elem.text())")
                        try elem.getChildNodes().first?.remove()
                        if (currDef != nil) {
                            shogakuDefArray.append(Definition(definition: currDef!, exampleSentences: shogakuExampleSentenceArray))
                            shogakuExampleSentenceArray = []
                        }
                        currDef = try elem.text()
                    } else {
                        //print("Reibun: \(try elem.text())")
                        shogakuExampleSentenceArray.append(ExampleSentence(language: .JP, attributedString: AttributedString(stringLiteral: try elem.select("jae").first()?.text() ?? "")))
                        shogakuExampleSentenceArray.append(ExampleSentence(language: .JP, attributedString: AttributedString(stringLiteral: try elem.select("ja_cn").first()?.text() ?? "")))
                    }
                    for canJian in try doc.select("a") {
                        //print("参见: \(try canJian.text())")
                        //TODO: CanJian
                    }
                } else {
                    var tags: [Tag] = []
                    var definitionArray: [Definition] = []
                    
                    for partOfSpeech in partOfSpeechs {
                        tags.append(Tag(shortName: (try? partOfSpeech.attr("data-code")) ?? "", longName: (try? partOfSpeech.attr("title")) ?? ""))
                    }
                    
                    for sense in senses {
                        let glossary = try sense.select(".glossary")
                        let reibun = try sense.select(".example-container")
                        let xref = try sense.select(".xref-container")
                        let notes = try sense.select(".sense-note-container")
                        
                        var exampleSentences: [ExampleSentence] = []
                        
                        let definition = try glossary.first()?.getChildNodes().map({ elem in
                            if let txtNode = elem as? TextNode {
                                return txtNode.text()
                            } else {
                                return try (elem as? Element)?.text() ?? ""
                            }
                        }).joined(separator: "; ")
                        
                        for reibunElement in reibun {
                            if let jpElement = try reibunElement.select(".ex-sent-ja-content").first() {
                                exampleSentences.append(ExampleSentence(language: .JP, attributedString: translateHtmlIntoAttributedString(element: jpElement)))
                            }
                            if let enElement = try reibunElement.select(".ex-sent-en-content").first() {
                                exampleSentences.append(ExampleSentence(language: .EN, attributedString: translateHtmlIntoAttributedString(element: enElement)))
                            }
                        }
                        
                        definitionArray.append(Definition(definition: definition ?? "", exampleSentences: exampleSentences))
                    }
                    
                    definitionGroupArrays.append(DefinitionGroup(tags: tags, definitions: definitionArray))
                    
                    // TODO: glossary and reibun pass as html
                    //print ("Definition: \(try glossary.text()) and Reibun: \(try reibun.text())")
                }
            }
            if currDef != nil {
                shogakuDefArray.append(Definition(definition: currDef!, exampleSentences: shogakuExampleSentenceArray))
                definitionGroupArrays.append(DefinitionGroup(tags: [], definitions: shogakuDefArray))
            }
        } catch {
            print("\(error) occurred, skipping")
        }
        return definitionGroupArrays
    }
    
    private func translateHtmlIntoAttributedString(element: SwiftSoup.Element) -> AttributedString {
        var attributedString = AttributedString()
        for child in element.getChildNodes() {
            if let textNode = child as? TextNode {
                attributedString.append(AttributedString(stringLiteral: textNode.text()))
            } else {
                do {
                    if let elementNode = child as? Element {
                        if elementNode.tagName() == "ruby" {
                            if let textNode = elementNode.getChildNodes().first as? TextNode, let furiganaNode = try elementNode.select("rt").first() {
                                attributedString.append(try generateFuriganaFor(word: textNode.text(), furigana: furiganaNode.text()))
                            } else {
                                attributedString.append(AttributedString(stringLiteral: try elementNode.text()))
                            }
                        } else {
                            attributedString.append(translateHtmlIntoAttributedString(element: elementNode))
                        }
                    }
                } catch {
                    print("failed in parsing a certain part of html \(error)")
                }
            }
        }
        
        return attributedString
    }
}
