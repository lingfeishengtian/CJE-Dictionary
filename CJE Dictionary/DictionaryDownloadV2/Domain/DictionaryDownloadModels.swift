import Foundation

enum DictionaryArtifactType: String, Codable, Hashable, CaseIterable {
    case zip
    case sqlite
    case binary
}

struct DictionaryID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ value: String) {
        self.rawValue = value
    }
}

struct DictionaryManifestItem: Hashable, Codable, Sendable {
    let id: DictionaryID
    let displayName: String
    let downloadURL: URL
    let artifactType: DictionaryArtifactType
    let version: Int
    let minAppVersion: String
    let minBuildNumber: Int
}

struct DictionaryInstallRecord: Hashable, Codable, Sendable {
    let id: DictionaryID
    let sourceURL: URL
    let installedVersion: Int
    let installedAt: Date
    let installPath: URL
}

struct DictionaryJobProgress: Hashable, Codable, Sendable {
    let completedBytes: Int64
    let totalBytes: Int64?

    var fractionCompleted: Double {
        guard let totalBytes, totalBytes > 0 else { return 0 }
        return max(0, min(1, Double(completedBytes) / Double(totalBytes)))
    }
}

enum DictionaryJobState: Hashable, Codable, Sendable {
    case queued
    case downloading(progress: DictionaryJobProgress)
    case downloaded(tempFile: URL)
    case installing
    case installed(record: DictionaryInstallRecord)
    case failed(message: String)
    case cancelled
}

struct DictionaryJobSnapshot: Hashable, Sendable {
    let id: DictionaryID
    let state: DictionaryJobState
    let updatedAt: Date
}
