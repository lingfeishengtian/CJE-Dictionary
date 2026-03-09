import Foundation

actor FileDictionaryCatalogStore: DictionaryCatalogStore {
    private struct CatalogPayload: Codable {
        let records: [DictionaryInstallRecord]
    }

    private let fileManager: FileManager
    private let paths: DictionaryInstallPaths

    init(
        fileManager: FileManager = .default,
        paths: DictionaryInstallPaths = DictionaryInstallPaths()
    ) {
        self.fileManager = fileManager
        self.paths = paths
    }

    func loadInstallRecords() async throws -> [DictionaryID: DictionaryInstallRecord] {
        let path = paths.catalogStoreFilePath
        guard fileManager.fileExists(atPath: path.path()) else {
            return [:]
        }

        let data = try Data(contentsOf: path)
        let payload = try JSONDecoder().decode(CatalogPayload.self, from: data)
        return Dictionary(uniqueKeysWithValues: payload.records.map { ($0.id, $0) })
    }

    func saveInstallRecords(_ records: [DictionaryID: DictionaryInstallRecord]) async throws {
        let payload = CatalogPayload(records: records.values.sorted { $0.id.rawValue < $1.id.rawValue })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        try fileManager.createDirectory(at: paths.documentsDirectory, withIntermediateDirectories: true)

        let tempURL = paths.catalogStoreFilePath.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)

        if fileManager.fileExists(atPath: paths.catalogStoreFilePath.path()) {
            try fileManager.removeItem(at: paths.catalogStoreFilePath)
        }
        try fileManager.moveItem(at: tempURL, to: paths.catalogStoreFilePath)
    }
}
