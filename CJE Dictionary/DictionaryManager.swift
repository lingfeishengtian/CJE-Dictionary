//
//  YomichanFileParser.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/31/23.
//

import Foundation
import ZIPFoundation

func unzipDatabase(urlOfZip: URL, exportFolder: URL) throws {
    do{
        try FileManager.default.unzipItem(at: urlOfZip, to: exportFolder)
        try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
    } catch {
        throw error
    }
    
//    defer {
//        do {
//            try FileManager.default.removeItem(at: exportFolder)
//        } catch {
//            print("Unable to delete zip export folder")
//        }
//    }
}

enum DictionaryParserError: Error {
    case runtimeError(String)
}

enum DictEntryType {
    case Definition
    case Link
}
