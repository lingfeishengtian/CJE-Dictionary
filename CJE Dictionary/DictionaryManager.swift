//
//  YomichanFileParser.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/31/23.
//

import Foundation
import ZIPFoundation
import SQLite

enum DICTIONARY_NAMES: String, CaseIterable, Codable {
    case jitendex = "jitendexDB"
    case shogakukanjcv3 = "Shogakukanjcv3DB"
    
    // from $0 to $1
    func type() -> LanguageToLanguage {
        switch self {
        case .jitendex:
            return (.JP, .EN)
        case .shogakukanjcv3:
            return (.JP, .CN)
        }
    }
}

class DownloadSessionQueue {
    private var urlSessionDownloadTaskQueue: [(URLSessionDownloadTask, String)] = []
    
    func numberOfSessions () -> Int {
        return urlSessionDownloadTaskQueue.count
    }
    
    func push(_ urlSession: URLSessionDownloadTask, dictName: String) {
        urlSessionDownloadTaskQueue.append((urlSession, dictName))
        
        if (urlSessionDownloadTaskQueue.count == 1) {
            urlSession.resume()
        }
    }
    
    func getCurrentDictionaryName() -> String? {
        if (!urlSessionDownloadTaskQueue.isEmpty) {
            return urlSessionDownloadTaskQueue[0].1
        }
        return nil
    }
    
    func pop() {
        if !urlSessionDownloadTaskQueue.isEmpty {
            urlSessionDownloadTaskQueue.remove(at: 0)
        }
        if (!urlSessionDownloadTaskQueue.isEmpty) {
            urlSessionDownloadTaskQueue[0].0.resume()
        }
    }
}

class DictionaryManager : NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var progress = Float(0.0)
    let queue = OperationQueue()
    let downloadSessionQueue = DownloadSessionQueue()
    
    let sessions: Int
    var completed = 0
    
    init(sessions: Int) {
        self.sessions = sessions
    }
    
    var isZip = false
    
    private let dictionaryLinks = [
        DICTIONARY_NAMES.jitendex.rawValue: "https://raw.githubusercontent.com/lingfeishengtian/CJE-Dictionary/main/CJE%20Dictionary/Dictionaries/jitendexDB.zip",
        DICTIONARY_NAMES.shogakukanjcv3.rawValue: "https://github.com/lingfeishengtian/CJE-Dictionary/raw/main/CJE%20Dictionary/Dictionaries/Shogakukanjcv3DB.zip",
        "kanjidict2": "https://github.com/lingfeishengtian/CJE-Dictionary/raw/main/CJE%20Dictionary/Dictionaries/KANJIDIC2_cleaned.db"
    ]
    
    var downloadSession : URLSession {
        URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: queue)
    }
    
    func downloadAllAvailableLinks() {
        if downloadSessionQueue.numberOfSessions() > 0 {
            print("Already downloading")
            return
        }
        for (name, url) in dictionaryLinks {
            if !doesDictionaryExist(dictName: name), let urlType = URL(string: url) {
                download(with: urlType, dictionaryName: name)
            } else {
                completed += 1
            }
        }
        
        if completed == sessions {
            self.progress = 1.0
        }
    }
    
    func getCurrentlyInstalledDictionaries(filterPreinstalled: Bool = false) -> [String] {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            var installedDictionaries = try FileManager.default.contentsOfDirectory(atPath: documentsDir.path()).filter({ $0 != ".DS_Store" })
            if filterPreinstalled {
                for dict in dictionaryLinks.keys {
                    installedDictionaries.removeAll(where: { $0 == dict || $0 == dict + ".db" })
                }
            }
            return installedDictionaries
        } catch {
            print("Could not get installed dictionaries \(error)")
        }
        return []
    }
    
    func deleteAllDictionaries() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        for fileFolder in getCurrentlyInstalledDictionaries(filterPreinstalled: true) {
            do {
                try FileManager.default.removeItem(at: documentsDir.appending(path: fileFolder))
            } catch {
                print("Couldn't delete \(fileFolder) since \(error)")
            }
        }
    }
    
    func getPreinstalledDictionaries() -> [String] {
        return dictionaryLinks.keys.uniqueElements
    }
    
    func download(with url: URL, dictionaryName: String) {
        print("Start download")
        
        errorMessage = ""
        progress = 0.01
        let task = downloadSession.downloadTask(with: url)
        downloadSessionQueue.push(task, dictName: dictionaryName)
    }
    
    func doesDictionaryExist(dictName: String) -> Bool {
        return FileManager.default.fileExists(atPath: exportFolderOf(dictionary: dictName).path()) || FileManager.default.fileExists(atPath: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(component: dictName, directoryHint: .notDirectory).appendingPathExtension("db").path())
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let currentDictionaryName = downloadSessionQueue.getCurrentDictionaryName() else {
            return
        }
        let isZip = isFileZip(pathToFile: location.path())
        let baseFilePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(component: currentDictionaryName, directoryHint: .notDirectory)
        let finalDestination = isZip ? baseFilePath.appendingPathExtension("zip") : baseFilePath.appendingPathExtension("db")
        do {
            try FileManager.default.copyItem(at: location, to: finalDestination)
            if isZip {
                try unzipDatabase(urlOfZip: finalDestination, exportFolder: exportFolderOf(dictionary: currentDictionaryName))
            }
        }catch {
            print("Failed to install \(currentDictionaryName) with error \(error)")
        }
        
        do {
            if isZip {
                try FileManager.default.removeItem(at: finalDestination)
            }
            try FileManager.default.removeItem(at: location)
        } catch {
            print("Unable to delete file at \(location.path()) due to \(error)")
        }
        
        downloadSessionQueue.pop()
        print(self.progress)
        completed += 1
        
        if (sessions == completed) {
            completed = 0
            self.progress = 1.0
            setupDictionaries()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async { [self] in
            var newProg = (Float(totalBytesWritten)/Float(totalBytesExpectedToWrite)) / Float(sessions) + (Float(1.0) / Float(sessions)) * Float(completed)
            if newProg >= 1.0 {
                newProg = 0.99
            }
            self.progress = newProg
            print(self.progress, Float(totalBytesWritten), Float(totalBytesExpectedToWrite), Float(sessions), Float(completed))
        }
    }
    
    var errorMessage = ""
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if error == nil {
            return
        }
        errorMessage = error?.localizedDescription ?? ""
        self.progress = (Float(1.0) / Float(sessions)) * Float(completed)
        print("Error: \(String(describing: error))")
        completed += 1
        downloadSessionQueue.pop()
    }
}

func isFileZip(pathToFile: String) -> Bool {
    if let fh = FileHandle(forReadingAtPath: pathToFile) {
        let data = fh.readData(ofLength: 4)
        fh.closeFile()
        if data.starts(with: [0x50, 0x4b, 0x03, 0x04]) {
            return true
        }
    }
    return false
}

func unzipDatabase(urlOfZip: URL, exportFolder: URL) throws {
    try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
    try FileManager.default.unzipItem(at: urlOfZip, to: exportFolder)
}

enum DictionaryParserError: Error {
    case runtimeError(String)
}

let DatabaseConnections: [DICTIONARY_NAMES:Connection] = {
    var ret: [DICTIONARY_NAMES:Connection] = [:]
    for dictName in DICTIONARY_NAMES.allCases {
        do {
            ret[dictName] = try Connection(exportFolderOf(dictionary: dictName.rawValue).appending(path: dictName.rawValue.dropLast("DB".count), directoryHint: .notDirectory).appendingPathExtension("db").path())
        } catch {
            print("Unable to connect to \(dictName)")
        }
    }
    return ret
}()

func setupDictionaries() {
    for dbConnection in DatabaseConnections.values {
        do {
            // ENSURE SEARCH IS USING INDEX
            //            let plan = try dbConnection.prepareRowIterator("EXPLAIN QUERY PLAN SELECT * FROM wordIndex INNER JOIN \"word\" USING (\"id\") WHERE wort LIKE \"あ%\";")
            //            while let a = plan.next() {
            //                print(a)
            //            }
            
            // Substring works differently here, you need to -1 at the end for some reason
            try dbConnection.execute("""
            CREATE TABLE "wordIndex" (
                            "id"    INTEGER NOT NULL,
                            "wort"    TEXT NOT NULL,
                            FOREIGN KEY(id) REFERENCES word(id)
                        );
            WITH cte AS (
                                SELECT id, '' w, w || '|' s
                                FROM word
                                UNION ALL
                                SELECT id,
                                       SUBSTR(s, 0, INSTR(s, '|') - 1),
                                       SUBSTR(s, INSTR(s, '|') + 1)
                                FROM cte
                                WHERE s <> ''
                            )
                            INSERT INTO wordIndex (id, wort)
                            SELECT id, w
                            FROM cte
                            WHERE w <> '';
            DELETE FROM wordIndex WHERE wort LIKE "%【%】%";
            CREATE INDEX wordIndex_w_idx ON wordIndex(wort COLLATE NOCASE);
            ANALYZE;
            """)
        } catch {
            print("DB Connection warning: \(error)")
        }
    }
}
