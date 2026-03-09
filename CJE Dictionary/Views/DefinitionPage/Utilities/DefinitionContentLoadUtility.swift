import Foundation

struct DefinitionContentLoadResult {
    let groups: [DefinitionGroup]
    let fallbackText: String?
    let errorMessage: String?
}

enum DefinitionContentLoadUtility {
    static func loadDefinition(
        dictionary: any DictionaryProtocol,
        key: SearchResultKey
    ) async -> DefinitionContentLoadResult {
        var groups: [DefinitionGroup] = []
        var fallbackText: String?
        var errorMessage: String?

        do {
            groups = try await dictionary.getDefinitionGroups(fromKey: key)
        } catch {
            errorMessage = error.localizedDescription
        }

        if groups.isEmpty,
           let recordData = dictionary.getRecordData(fromKey: key),
           let html = String(data: recordData, encoding: .utf8)
            ?? String(data: recordData, encoding: .utf16)
            ?? String(data: recordData, encoding: .unicode) {
            fallbackText = htmlToPlainText(html)
        }

        return DefinitionContentLoadResult(
            groups: groups,
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
