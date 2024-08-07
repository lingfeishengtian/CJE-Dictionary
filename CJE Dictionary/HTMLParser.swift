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
import WebKit

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
        self.attributedString = try AttributedString(markdown: try container.decode(String.self, forKey: .attributedString), including: \.coreText, options: .init(allowsExtendedAttributes: true))
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

struct Tag : Identifiable, Hashable, Codable {
    let shortName: String
    let longName: String
    var id: String {
        shortName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(shortName)
    }
}

struct Definition : Codable {
    var id: String {
        return definition
    }
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

class ParserNavigationDelegate: NSObject, WKNavigationDelegate, ObservableObject {
    @Published var showShowErrorMessage = false
    @Published var errorMessage: String = ""
    @Published var showLoading = true
    var cachedDefinitions: [LanguageToLanguage: [DefinitionGroup]] = [:]
    var dbWord: DatabaseWord?
    let webView: WKWebView
    
    override init() {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        var returnDefinitionGroups: [DefinitionGroup] = []
        errorMessage = ""
        if dbWord == nil {
            errorMessage = "No dictionary name found"
            return
        }
        do {
            let jsString = try String(contentsOf: exportFolderOf(dictionary: dbWord!.dict.rawValue).appending(path: "Script.js", directoryHint: .notDirectory))
            webView.evaluateJavaScript(jsString) { retString, error in
                if error != nil {
                    self.errorMessage = error?.localizedDescription ?? ""
                } else {
                    do {
                        returnDefinitionGroups = try JSONDecoder().decode([DefinitionGroup].self, from: (retString as? String)?.data(using: .utf16) ?? Data())
                        
                        self.cachedDefinitions[self.dbWord!.dict.type()] = returnDefinitionGroups
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                }
                
                self.showLoading = false
                if !self.errorMessage.isEmpty {
                    self.showShowErrorMessage = true
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func doesLanguageExistInCache(lang: Language) -> Bool{
        return cachedDefinitions.contains(where: { $0.key.resultsLanguage == lang })
    }
    
    func getDefinitionGroupInCache(for lang: Language) -> [DefinitionGroup] {
        if doesLanguageExistInCache(lang: lang) {
            return cachedDefinitions.first(where: { $0.key.resultsLanguage == lang })?.value ?? []
        } else {
            return []
        }
    }
    
    func initiateHTMLParse(dbWord: DatabaseWord) {
        //TODO: implement checking if dict exist logic here
        self.showLoading = true
        webView.navigationDelegate = self
        self.dbWord = dbWord
        webView.loadHTMLString(dbWord.meaning, baseURL: nil)
    }
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
    
    @available(*, deprecated, renamed: "initiateHTMLParse", message: "HTML Parser Plugin")
    func parseDefinitionHTML(otherHTML: String? = nil) -> [DefinitionGroup] {
        let html = otherHTML ?? meaning
        var definitionGroupArrays: [DefinitionGroup] = []
        do {
            let doc = try SwiftSoup.parse(html)
            
            let pronounciationElements = try attemptTwoSelectors(doc: doc, selectorA: ".pronunciation-text", selectorB: ".pinyin_h")
            var pronounciationText = try pronounciationElements.text(trimAndNormaliseWhitespace: true)
            let definitionsAndReibun = try attemptTwoSelectors(doc: doc, selectorA: ".sense-group", selectorB: ".description:last-of-type > [data-orgtag]")
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
            
            var shogakuTags: [Tag] = []
            
            for elem in definitionsAndReibun {
                let partOfSpeechs = try elem.select(".tag.part-of-speech-info")
                let senses = try elem.select(".sense")
                
                // TODO: 参见
                if (senses.isEmpty()) {
                    // TODO: glossary and reibun pass as html
                    if (try elem.attr("data-orgtag") == "meaning") {
                        if elem.hasAttr("level") && elem.hasAttr("no") {
                            let level = try elem.attr("level")
                            _ = try elem.attr("no")
                            
                            //print("Definition: \(try elem.text())")
                            try elem.getChildNodes().first?.remove()
                            if (currDef != nil) {
                                shogakuDefArray.append(Definition(definition: currDef!, exampleSentences: shogakuExampleSentenceArray))
                                shogakuExampleSentenceArray = []
                                
                                if level == "1" {
                                    definitionGroupArrays.append(DefinitionGroup(tags: shogakuTags, definitions: shogakuDefArray))
                                    shogakuTags = []
                                    shogakuDefArray = []
                                    currDef = nil
                                }
                            }
                            
                            if level == "1" {
                                let tagName = try elem.text().trimmingCharacters(in: ["]", "["])
                                shogakuTags.append(Tag(shortName: tagName, longName: tagName))
                            } else {
                                currDef = try elem.text()
                            }
                        } else {
                            if let cDef = currDef {
                                currDef = cDef + "\n" + (try elem.text())
                            } else {
                                currDef = try elem.text()
                            }
                        }
                    } else if (try elem.attr("data-orgtag") == "subhead") {
                        if let meaning = try elem.select("[data-orgtag=\"meaning\"]").first(), let subheadword = try elem.select("[data-orgtag=\"subheadword\"]").first() {
                            if (currDef != nil) {
                                shogakuDefArray.append(Definition(definition: currDef!, exampleSentences: shogakuExampleSentenceArray))
                                shogakuExampleSentenceArray = []
                                
                                definitionGroupArrays.append(DefinitionGroup(tags: shogakuTags, definitions: shogakuDefArray))
                                shogakuTags = []
                                shogakuDefArray = []
                                currDef = nil
                            }
                            if elem.hasAttr("type") {
                                shogakuTags.append(Tag(shortName: try elem.attr("type"), longName: try elem.attr("type")))
                            }
                            for span in try meaning.select("span") {
                                shogakuTags.append(Tag(shortName: try span.text(), longName: try span.text()))
                            }
                            
                            var def = ""
                            for childNode in meaning.getChildNodes() {
                                if let tNode = childNode as? TextNode {
                                    def += tNode.text()
                                }
                            }
                            
                            definitionGroupArrays.append(DefinitionGroup(tags: shogakuTags, definitions: [Definition(definition: def, exampleSentences: [ExampleSentence(language: .JP, attributedString: AttributedString(stringLiteral: try subheadword.text()))])]))
                            shogakuTags = []
                        }
                    } else {
                        //print("Reibun: \(try elem.text())")
                        shogakuExampleSentenceArray.append(ExampleSentence(language: .JP, attributedString: AttributedString(stringLiteral: try elem.select("jae").first()?.text() ?? "")))
                        shogakuExampleSentenceArray.append(ExampleSentence(language: .CN, attributedString: AttributedString(stringLiteral: try elem.select("ja_cn").first()?.text() ?? "")))
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
                        
                        if let note = notes.first() {
                            exampleSentences.append(ExampleSentence(language: nil, attributedString: translateHtmlIntoAttributedString(element: note)))
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
                        } else if elementNode.tagName() == "legend" {
                            // attributedString.append(try AttributedString("\(elementNode.text()): ", attributes: AttributeContainer([.font: UIFont.boldSystemFont(ofSize: 17)])))
                        } else if elementNode.hasClass("sense-note-icon") {
                            attributedString.append(AttributedString(stringLiteral: try elementNode.text() + " "))
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
