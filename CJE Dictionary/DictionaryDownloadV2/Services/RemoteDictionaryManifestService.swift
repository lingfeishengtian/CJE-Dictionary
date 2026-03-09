import Foundation

struct RemoteDictionaryManifestService: DictionaryManifestService {
    private let session: URLSession
    private let manifestURL: URL

    init(
        session: URLSession = .shared,
        manifestURL: URL = URL(string: "https://raw.githubusercontent.com/lingfeishengtian/CJE-Dictionary/main/CJE%20Dictionary/Dictionaries/manifest.json")!
    ) {
        self.session = session
        self.manifestURL = manifestURL
    }

    func fetchManifest() async throws -> [DictionaryManifestItem] {
        let (data, response) = try await session.data(from: manifestURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DictionaryDownloadError.manifestFetchFailed("Unexpected response code")
        }

        guard !data.isEmpty else {
            throw DictionaryDownloadError.manifestDecodeFailed("Empty versions payload")
        }

        do {
            let decoder = JSONDecoder()
            if let payload = try? decoder.decode(RemoteManifestPayload.self, from: data) {
                return payload.items
                    .map { $0.asDictionaryManifestItem }
                    .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            }

            let items = try decoder.decode([RemoteManifestItem].self, from: data)
            return items
                .map { $0.asDictionaryManifestItem }
                .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        } catch {
            throw DictionaryDownloadError.manifestDecodeFailed(error.localizedDescription)
        }
    }
}

private struct RemoteManifestPayload: Decodable {
    let items: [RemoteManifestItem]
}

private struct RemoteManifestItem: Decodable {
    let id: String
    let displayName: String
    let description: String?
    let downloadURL: URL
    let artifactType: DictionaryArtifactType
    let version: Int
    let minAppVersion: String
    let minBuildNumber: Int

    var asDictionaryManifestItem: DictionaryManifestItem {
        DictionaryManifestItem(
            id: DictionaryID(id),
            displayName: displayName,
            description: description,
            downloadURL: downloadURL,
            artifactType: artifactType,
            version: version,
            minAppVersion: minAppVersion,
            minBuildNumber: minBuildNumber
        )
    }
}
