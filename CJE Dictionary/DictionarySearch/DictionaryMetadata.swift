import Foundation

enum LocalDictionaryBackend: String, Decodable, Sendable {
    case mdictOptimized
    case realmMongo
    case kanjiSqlite
    case sqlite

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self).lowercased()

        switch raw {
        case "mdictoptimized": self = .mdictOptimized
        case "realmmongo": self = .realmMongo
        case "kanjisqlite": self = .kanjiSqlite
        case "sqlite": self = .sqlite
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported backend: \(raw)"
            )
        }
    }
}

struct LocalDictionaryMetadata: Decodable, Sendable {
    let id: String
    let displayName: String
    let backend: LocalDictionaryBackend
    let parser: String?
    let searchLanguage: String
    let resultsLanguage: String
    let files: [String: String]
}

enum LocalDictionaryMetadataDecoder {
    private static let decoder = JSONDecoder()

    static func decode(from data: Data) throws -> LocalDictionaryMetadata {
        try decoder.decode(LocalDictionaryMetadata.self, from: data)
    }

    static func decode(from fileURL: URL) throws -> LocalDictionaryMetadata {
        let data = try Data(contentsOf: fileURL)
        return try decode(from: data)
    }
}
