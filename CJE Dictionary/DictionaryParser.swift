//
//  YomichanFileParser.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/31/23.
//

import Foundation
import ZIPFoundation

let TMP_DIR = FileManager.default.temporaryDirectory
func enumerateDictionaryEntries(urlOfZip: URL, onEntryReceived:(String, String, DictEntryType) -> Void) throws {
    let exportFolder = TMP_DIR.appending(component: UUID().uuidString, directoryHint: .isDirectory)
    do{
        try FileManager.default.unzipItem(at: urlOfZip, to: exportFolder)
        try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
    } catch {
        throw error
    }
    
    defer {
        do {
            try FileManager.default.removeItem(at: exportFolder)
        } catch {
            print("Unable to delete zip export folder")
        }
    }
    
    let enumerator = FileManager.default.enumerator(atPath: exportFolder.path())
    let txtFilePath = exportFolder.appending(path: (enumerator?.allObjects as! [String]).filter{$0.contains(".txt")}[0], directoryHint: .notDirectory)
    let fp = freopen(txtFilePath.path(), "r", stdin)
    
    if fp == nil {
        perror(txtFilePath.path())
        throw DictionaryParserError.runtimeError("Txt file path cannot be found")
    }
    
    defer {
        fclose(fp)
    }
    
    var state = 0
    var term = ""
    var html = ""
    var type = DictEntryType.Definition
    while let line = readLine() {
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if (state == 0) {
            term = cleaned
            state += 1
        } else {
            if (cleaned.starts(with: "@@@LINK=")) {
                type = .Link
                html = String(cleaned.dropFirst("@@@LINK=".count))
            } else if (cleaned != "</>") {
                html += cleaned
            } else {
                onEntryReceived(term, html, type)
                term = ""
                html = ""
                state = 0
                type = .Definition
            }
        }
    }
}

enum DictionaryParserError: Error {
    case runtimeError(String)
}

enum DictEntryType {
    case Definition
    case Link
}
