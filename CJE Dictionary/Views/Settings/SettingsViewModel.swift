import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    private static let dictionarySearchOrderKey = "dictionarySearchOrder"

    @Published var dictionaryURLInput: String = ""
    @Published var userFacingError: String?

    private let coordinator: DefaultDictionaryDownloadCoordinator
    private let settingsStore: any DictionarySettingsStore

    init(
        coordinator: DefaultDictionaryDownloadCoordinator,
        settingsStore: any DictionarySettingsStore
    ) {
        self.coordinator = coordinator
        self.settingsStore = settingsStore
    }

    func refresh() async {
        await coordinator.refreshManifest()
    }

    func install(_ id: DictionaryID) async {
        await coordinator.install(id)
    }

    func installCustomFromInput() async {
        let cleanURL = dictionaryURLInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanURL.isEmpty else {
            userFacingError = "Dictionary URL cannot be empty."
            return
        }

        do {
            _ = try await coordinator.installCustom(urlString: cleanURL)
            dictionaryURLInput = ""
        } catch {
            userFacingError = error.localizedDescription
        }
    }

    func retry(_ id: DictionaryID) async {
        await coordinator.retry(id)
    }

    func cancel(_ id: DictionaryID) async {
        await coordinator.cancel(id)
    }

    func remove(_ id: DictionaryID) async {
        await coordinator.remove(id)
    }

    func canRemove(_ id: DictionaryID) -> Bool {
        true
    }

    func moveInstalledDictionaries(
        from source: IndexSet,
        to destination: Int,
        installedRecords: [DictionaryID: DictionaryInstallRecord]
    ) {
        var updated = orderedInstalledRecords(from: installedRecords)
        updated.move(fromOffsets: source, toOffset: destination)
        persistDictionarySearchOrder(from: updated)
        NotificationCenter.default.post(name: .dictionaryCatalogDidChange, object: nil)
    }

    func orderedInstalledRecords(from installedRecords: [DictionaryID: DictionaryInstallRecord]) -> [DictionaryInstallRecord] {
        let persistedOrder = settingsStore.stringArrayValue(for: Self.dictionarySearchOrderKey)
        var recordsByID = Dictionary(uniqueKeysWithValues: installedRecords.values.map { ($0.id.rawValue, $0) })

        var ordered: [DictionaryInstallRecord] = []
        ordered.reserveCapacity(recordsByID.count)

        for id in persistedOrder {
            if let record = recordsByID.removeValue(forKey: id) {
                ordered.append(record)
            }
        }

        let remaining = recordsByID.values.sorted { $0.id.rawValue < $1.id.rawValue }
        ordered.append(contentsOf: remaining)
        return ordered
    }

    func dismissError() {
        userFacingError = nil
    }

    func boolValue(for key: String, default defaultValue: Bool) -> Bool {
        settingsStore.boolValue(for: key, default: defaultValue)
    }

    func setBoolValue(_ value: Bool, for key: String) {
        settingsStore.setBoolValue(value, for: key)
    }

    private func persistDictionarySearchOrder(from records: [DictionaryInstallRecord]) {
        settingsStore.setStringArrayValue(records.map { $0.id.rawValue }, for: Self.dictionarySearchOrderKey)
    }
}
