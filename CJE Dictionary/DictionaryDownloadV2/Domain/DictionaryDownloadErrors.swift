import Foundation

enum DictionaryDownloadError: LocalizedError, Sendable {
    case invalidManifestURL
    case manifestFetchFailed(String)
    case manifestDecodeFailed(String)
    case downloadFailed(String)
    case installFailed(String)
    case fileValidationFailed(String)
    case unsupportedArtifactType(String)

    var errorDescription: String? {
        switch self {
        case .invalidManifestURL:
            return "The manifest URL is invalid."
        case .manifestFetchFailed(let message):
            return "Failed to fetch dictionary manifest: \(message)"
        case .manifestDecodeFailed(let message):
            return "Failed to parse dictionary manifest: \(message)"
        case .downloadFailed(let message):
            return "Dictionary download failed: \(message)"
        case .installFailed(let message):
            return "Dictionary installation failed: \(message)"
        case .fileValidationFailed(let message):
            return "Downloaded file validation failed: \(message)"
        case .unsupportedArtifactType(let artifact):
            return "Unsupported dictionary artifact type: \(artifact)"
        }
    }
}
