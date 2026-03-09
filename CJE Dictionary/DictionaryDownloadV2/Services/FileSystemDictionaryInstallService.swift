import Foundation
import ZIPFoundation

struct FileSystemDictionaryInstallService: DictionaryInstallService {
    private let fileManager: FileManager
    private let paths: DictionaryInstallPaths

    init(
        fileManager: FileManager = .default,
        paths: DictionaryInstallPaths = DictionaryInstallPaths()
    ) {
        self.fileManager = fileManager
        self.paths = paths
    }

    func install(item: DictionaryManifestItem, downloadedFileURL: URL) async throws -> DictionaryInstallRecord {
        try fileManager.createDirectory(at: paths.documentsDirectory, withIntermediateDirectories: true)

        switch item.artifactType {
        case .zip:
            let destination = paths.dictionaryDirectory(for: item.id)
            if fileManager.fileExists(atPath: destination.path()) {
                try fileManager.removeItem(at: destination)
            }

            let staging = paths.documentsDirectory.appending(path: "\(item.id.rawValue)_staging", directoryHint: .isDirectory)
            if fileManager.fileExists(atPath: staging.path()) {
                try fileManager.removeItem(at: staging)
            }
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: downloadedFileURL, to: staging)
            try fileManager.moveItem(at: staging, to: destination)

            return DictionaryInstallRecord(
                id: item.id,
                sourceURL: item.downloadURL,
                installedVersion: item.version,
                installedAt: Date(),
                installPath: destination
            )

        case .sqlite, .binary:
            let destination: URL
            if item.downloadURL.pathExtension.lowercased() == "realm" {
                destination = paths.realmFilePath(for: item.id)
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            } else {
                destination = paths.sqliteFilePath(for: item.id)
            }

            if fileManager.fileExists(atPath: destination.path()) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: downloadedFileURL, to: destination)

            return DictionaryInstallRecord(
                id: item.id,
                sourceURL: item.downloadURL,
                installedVersion: item.version,
                installedAt: Date(),
                installPath: destination
            )
        }
    }

    func removeInstalledDictionary(id: DictionaryID) async throws {
        let dir = paths.dictionaryDirectory(for: id)
        if fileManager.fileExists(atPath: dir.path()) {
            try fileManager.removeItem(at: dir)
        }

        let sqlite = paths.sqliteFilePath(for: id)
        if fileManager.fileExists(atPath: sqlite.path()) {
            try fileManager.removeItem(at: sqlite)
        }

        let realmFile = paths.realmFilePath(for: id)
        if fileManager.fileExists(atPath: realmFile.path()) {
            try fileManager.removeItem(at: realmFile)
        }
    }

    func isInstalled(id: DictionaryID) async -> Bool {
        let dir = paths.dictionaryDirectory(for: id)
        let sqlite = paths.sqliteFilePath(for: id)
        let realmFile = paths.realmFilePath(for: id)
        return fileManager.fileExists(atPath: dir.path())
            || fileManager.fileExists(atPath: sqlite.path())
            || fileManager.fileExists(atPath: realmFile.path())
    }
}
