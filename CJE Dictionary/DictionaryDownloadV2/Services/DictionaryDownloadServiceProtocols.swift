import Foundation

protocol DictionaryManifestService: Sendable {
    func fetchManifest() async throws -> [DictionaryManifestItem]
}

protocol DictionaryCatalogStore: Sendable {
    func loadInstallRecords() async throws -> [DictionaryID: DictionaryInstallRecord]
    func saveInstallRecords(_ records: [DictionaryID: DictionaryInstallRecord]) async throws
}

protocol DictionaryDownloadService: Sendable {
    func enqueue(_ item: DictionaryManifestItem) async
    func cancel(id: DictionaryID) async
    func cancelAll() async
    func snapshots() -> AsyncStream<DictionaryJobSnapshot>
}

protocol DictionaryInstallService: Sendable {
    func install(item: DictionaryManifestItem, downloadedFileURL: URL) async throws -> DictionaryInstallRecord
    func removeInstalledDictionary(id: DictionaryID) async throws
    func isInstalled(id: DictionaryID) async -> Bool
}

protocol DictionarySettingsStore: Sendable {
    func boolValue(for key: String, default defaultValue: Bool) -> Bool
    func setBoolValue(_ value: Bool, for key: String)
    func stringArrayValue(for key: String) -> [String]
    func setStringArrayValue(_ value: [String], for key: String)
}
