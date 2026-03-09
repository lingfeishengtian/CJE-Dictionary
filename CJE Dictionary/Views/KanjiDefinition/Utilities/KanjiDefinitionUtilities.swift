import Foundation
import UIKit

struct KanjiDefinitionLoadResult {
    let definitionGroups: [DefinitionGroup]
    let kanjiInfo: KanjiInfo?
    let fallbackText: String?
    let errorMessage: String
}

enum KanjiDefinitionUtilities {
    static func loadDefinition(
        key: SearchResultKey,
        dictionary: DictionaryProtocol?
    ) async -> KanjiDefinitionLoadResult {
        guard let dictionary else {
            return KanjiDefinitionLoadResult(
                definitionGroups: [],
                kanjiInfo: nil,
                fallbackText: nil,
                errorMessage: "Dictionary context unavailable for this result."
            )
        }

        var definitionGroups: [DefinitionGroup] = []
        var kanjiInfo: KanjiInfo?
        var errorMessage = ""

        do {
            if let kanjiDictionary = dictionary as? any KanjiDictionaryProtocol {
                kanjiInfo = try kanjiDictionary.getKanjiInfo(fromKey: key)
            }
            definitionGroups = try await dictionary.getDefinitionGroups(fromKey: key)
        } catch {
            errorMessage = error.localizedDescription
        }

        var fallbackText: String?
        if definitionGroups.isEmpty,
           let recordData = dictionary.getRecordData(fromKey: key),
           let html = String(data: recordData, encoding: .utf8)
            ?? String(data: recordData, encoding: .utf16)
            ?? String(data: recordData, encoding: .unicode) {
            fallbackText = htmlToPlainText(html)
        }

        return KanjiDefinitionLoadResult(
            definitionGroups: definitionGroups,
            kanjiInfo: kanjiInfo,
            fallbackText: fallbackText,
            errorMessage: errorMessage
        )
    }

    static func htmlToPlainText(_ html: String) -> String {
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              )
        else {
            return html
        }

        return attributed.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
