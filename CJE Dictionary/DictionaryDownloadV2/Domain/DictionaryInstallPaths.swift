import Foundation

struct DictionaryInstallPaths {
    let documentsDirectory: URL

    init(fileManager: FileManager = .default) {
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func dictionaryDirectory(for id: DictionaryID) -> URL {
        documentsDirectory.appending(path: id.rawValue, directoryHint: .isDirectory)
    }

    func sqliteFilePath(for id: DictionaryID) -> URL {
        documentsDirectory
            .appending(component: id.rawValue, directoryHint: .notDirectory)
            .appendingPathExtension("db")
    }

    func realmFilePath(for id: DictionaryID) -> URL {
        dictionaryDirectory(for: id)
            .appending(component: id.rawValue, directoryHint: .notDirectory)
            .appendingPathExtension("realm")
    }

    var catalogStoreFilePath: URL {
        documentsDirectory.appending(path: "dictionary_catalog_v2.json", directoryHint: .notDirectory)
    }
}
