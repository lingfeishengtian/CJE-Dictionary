//
//  HistoryManager.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/31/23.
//

import Foundation

fileprivate let HISTORY_KEY = "searchHistory"
let MAX_HISTORY_COUNT = 50

var HistoryArray: [DatabaseWord] {
    get {
        if let retrieved = UserDefaults.group?.value(forKey: HISTORY_KEY) as? Data {
            return try! PropertyListDecoder().decode(Array<DatabaseWord>.self, from: retrieved)
        } else {
            return []
        }
//        UserDefaults.group?.array(forKey: HISTORY_KEY) as? [DatabaseWord] ?? []
    }
    set(newArr) {
        if newArr.count >= MAX_HISTORY_COUNT {
            saveHistory(arr: Array(newArr[0..<MAX_HISTORY_COUNT]))
        } else {
            saveHistory(arr: newArr)
        }
    }
}

@inline(__always) fileprivate func saveHistory(arr: [DatabaseWord]) {
    if let encoded = try? PropertyListEncoder().encode(arr) {
        UserDefaults.group?.set(encoded, forKey: HISTORY_KEY)
    }
}
