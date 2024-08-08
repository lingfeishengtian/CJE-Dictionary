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

class ParserNavigationDelegate: NSObject, WKNavigationDelegate, ObservableObject {
    @Published var errorMessage: String = ""
    @Published var showLoading = true
    private var cachedDefinitions: [LanguageToLanguage: [DefinitionGroup]]
    private var queue: [LanguageToLanguage: DatabaseWord]
    private let dbWord: DatabaseWord
    private var currentLanguage: Language?
    private let webView: WKWebView
    
    override private init() {
        cachedDefinitions = [:]
        queue = [:]
        dbWord = DatabaseWord(id: 0, dict: .jitendex, word: "", readingsString: "", meaning: "")
        webView = WKWebView()
        super.init()
    }
    
    init(databaseWord: DatabaseWord) {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        dbWord = databaseWord
        let lookupResults = lookupWord(word: dbWord)
        cachedDefinitions = lookupResults.definitions
        queue = lookupResults.queuedDefinitions
        
        super.init()
        self.webView.navigationDelegate = self
        if getResultingLanguages().count > 0 {
            self.initiateHTMLParse(language: getResultingLanguages().first!)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        var returnDefinitionGroups: [DefinitionGroup] = []
        errorMessage = ""
        do {
            let dict = queue.first(where: { $0.key.resultsLanguage == currentLanguage })!.value.dict
            let jsString = try String(contentsOf: exportFolderOf(dictionary: dict.rawValue).appending(path: "Script.js", directoryHint: .notDirectory))
            webView.evaluateJavaScript(jsString) { retString, error in
                if error != nil {
                    self.errorMessage = error?.localizedDescription ?? ""
                } else {
                    do {
                        returnDefinitionGroups = try JSONDecoder().decode([DefinitionGroup].self, from: (retString as? String)?.data(using: .utf16) ?? Data())
                        
                        self.queue.removeValue(forKey: dict.type())
                        self.cachedDefinitions[dict.type()] = returnDefinitionGroups
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                }
                
                self.showLoading = false
            }
        } catch {
            self.showLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    func getResultingLanguages() -> [Language] {
        var languages: [Language] = []
        for language in cachedDefinitions.keys.uniqueElements + queue.keys.uniqueElements {
            languages.append(language.resultsLanguage)
        }
        return languages.sorted(by: { $0.ordered < $1.ordered })
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
    
    func initiateHTMLParse(language: Language) {
        //TODO: implement checking if dict exist logic here
        self.showLoading = true
        if let meaningText = queue.first(where: { $0.key.resultsLanguage == language }) {
            self.currentLanguage = language
            webView.loadHTMLString(meaningText.value.meaning, baseURL: nil)
        }
    }
}

extension DatabaseWord {
    func generateAttributedStringTitle() -> AttributedString {
        var wordAttributedString = AttributedString(word)
        wordAttributedString.setAttributes(try! AttributeContainer([.font: UIFont(name: "HiraMinProN-W3", size: 25)!], including: \.uiKit))
        var pronounciations = AttributedString("【\(readings.filter({ $0 != word }).joined(separator: ", "))】")
        pronounciations.setAttributes(try! AttributeContainer([.font: UIFont(name: "HiraMinProN-W3", size: 15)!], including: \.uiKit))
        if readings.count > 1 {
            wordAttributedString.append(pronounciations)
        }
        return wordAttributedString
    }
}
