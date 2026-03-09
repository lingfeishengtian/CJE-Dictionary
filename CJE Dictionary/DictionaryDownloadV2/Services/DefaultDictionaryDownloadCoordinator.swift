import Foundation
import SwiftUI

@MainActor
final class DefaultDictionaryDownloadCoordinator: ObservableObject {
    @Published private(set) var manifestItems: [DictionaryManifestItem] = []
    @Published private(set) var jobs: [DictionaryID: DictionaryJobSnapshot] = [:]
    @Published private(set) var installedRecords: [DictionaryID: DictionaryInstallRecord] = [:]

    private let manifestService: any DictionaryManifestService
    private let downloadService: any DictionaryDownloadService
    private let installService: any DictionaryInstallService
    private let catalogStore: any DictionaryCatalogStore

    private var runtimeItems: [DictionaryID: DictionaryManifestItem] = [:]
    private var customItemIDs: Set<DictionaryID> = []
    private var snapshotObservationTask: Task<Void, Never>?

    init(
        manifestService: any DictionaryManifestService = RemoteDictionaryManifestService(),
        downloadService: any DictionaryDownloadService = URLSessionDictionaryDownloadService(),
        installService: any DictionaryInstallService = FileSystemDictionaryInstallService(),
        catalogStore: any DictionaryCatalogStore = FileDictionaryCatalogStore()
    ) {
        self.manifestService = manifestService
        self.downloadService = downloadService
        self.installService = installService
        self.catalogStore = catalogStore

        snapshotObservationTask = Task { [weak self] in
            guard let self else { return }
            let stream = downloadService.snapshots()
            for await snapshot in stream {
                await self.consumeSnapshot(snapshot)
            }
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                installedRecords = try await catalogStore.loadInstallRecords()
            } catch {
                print("Failed to load dictionary catalog: \(error)")
            }
            await refreshManifest()
        }
    }

    deinit {
        snapshotObservationTask?.cancel()
    }

    func refreshManifest() async {
        do {
            let fetchedItems = try await manifestService.fetchManifest().filter { isEligible($0) }

            let remoteByID = Dictionary(uniqueKeysWithValues: fetchedItems.map { ($0.id, $0) })
            var runtimeMergedByID = remoteByID
            var manifestMergedByID = remoteByID

            for (id, item) in runtimeItems where remoteByID[id] == nil {
                runtimeMergedByID[id] = item
                if !customItemIDs.contains(id) {
                    manifestMergedByID[id] = item
                }
            }

            manifestItems = manifestMergedByID.values
                .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            runtimeItems = runtimeMergedByID
        } catch {
            print("Failed to refresh manifest: \(error)")
        }
    }

    func install(_ id: DictionaryID) async {
        guard let item = runtimeItems[id] ?? manifestItems.first(where: { $0.id == id }) else { return }
        runtimeItems[id] = item
        jobs[id] = DictionaryJobSnapshot(id: id, state: .queued, updatedAt: Date())
        await downloadService.enqueue(item)
    }

    func installCustom(urlString: String) async throws -> DictionaryID {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw DictionaryDownloadError.invalidManifestURL
        }

        let inferredName = inferredDictionaryName(from: url)
        let id = DictionaryID(inferredName)
        if runtimeItems[id] != nil || installedRecords[id] != nil {
            throw DictionaryDownloadError.installFailed("Dictionary already exists: \(inferredName)")
        }

        let artifactType = artifactType(from: url)
        let item = DictionaryManifestItem(
            id: id,
            displayName: inferredName,
            downloadURL: url,
            artifactType: artifactType,
            version: 1,
            minAppVersion: "0",
            minBuildNumber: 0
        )

        customItemIDs.insert(id)
        runtimeItems[id] = item
        jobs[id] = DictionaryJobSnapshot(id: id, state: .queued, updatedAt: Date())
        await downloadService.enqueue(item)
        return id
    }

    func retry(_ id: DictionaryID) async {
        await install(id)
    }

    func cancel(_ id: DictionaryID) async {
        await downloadService.cancel(id: id)
    }

    func remove(_ id: DictionaryID) async {
        do {
            try await installService.removeInstalledDictionary(id: id)
            installedRecords.removeValue(forKey: id)
            try await catalogStore.saveInstallRecords(installedRecords)
            jobs.removeValue(forKey: id)
            notifyDictionaryCatalogDidChange()
        } catch {
            jobs[id] = DictionaryJobSnapshot(id: id, state: .failed(message: error.localizedDescription), updatedAt: Date())
        }
    }

    private func consumeSnapshot(_ snapshot: DictionaryJobSnapshot) async {
        jobs[snapshot.id] = snapshot

        guard case .downloaded(let tempFileURL) = snapshot.state else {
            return
        }

        guard let item = runtimeItems[snapshot.id] ?? manifestItems.first(where: { $0.id == snapshot.id }) else {
            jobs[snapshot.id] = DictionaryJobSnapshot(
                id: snapshot.id,
                state: .failed(message: "Manifest entry not found for downloaded dictionary."),
                updatedAt: Date()
            )
            return
        }

        jobs[snapshot.id] = DictionaryJobSnapshot(id: snapshot.id, state: .installing, updatedAt: Date())

        do {
            let record = try await installService.install(item: item, downloadedFileURL: tempFileURL)
            installedRecords[snapshot.id] = record
            try await catalogStore.saveInstallRecords(installedRecords)
            jobs[snapshot.id] = DictionaryJobSnapshot(id: snapshot.id, state: .installed(record: record), updatedAt: Date())

            if customItemIDs.contains(snapshot.id) {
                runtimeItems.removeValue(forKey: snapshot.id)
                customItemIDs.remove(snapshot.id)
                manifestItems.removeAll { $0.id == snapshot.id }
            }

            notifyDictionaryCatalogDidChange()
        } catch {
            jobs[snapshot.id] = DictionaryJobSnapshot(id: snapshot.id, state: .failed(message: error.localizedDescription), updatedAt: Date())
        }

        try? FileManager.default.removeItem(at: tempFileURL)
    }

    private func isEligible(_ item: DictionaryManifestItem) -> Bool {
        let buildString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let build = Int(buildString ?? "0") ?? 0
        return item.minBuildNumber <= build
    }

    private func artifactType(from url: URL) -> DictionaryArtifactType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "zip":
            return .zip
        case "db", "sqlite", "sqlite3":
            return .sqlite
        default:
            return .binary
        }
    }

    private func inferredDictionaryName(from url: URL) -> String {
        let fileName = url.deletingPathExtension().lastPathComponent
        let normalized = fileName
            .replacingOccurrences(of: ".realm", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? UUID().uuidString : normalized
    }

    private func notifyDictionaryCatalogDidChange() {
        NotificationCenter.default.post(name: .dictionaryCatalogDidChange, object: nil)
    }
}
