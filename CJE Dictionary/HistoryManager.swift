//
//  HistoryManager.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/31/23.
//

import Foundation

let HISTORY_KEY = "history"

var HistoryArray: [String] {
    get {
        UserDefaults.group?.stringArray(forKey: HISTORY_KEY) ?? []
    }
    set(newArr) {
        saveHistory(arr: newArr)
    }
}

@inline(__always) fileprivate func saveHistory(arr: [String]) {
    UserDefaults.group?.set(arr, forKey: HISTORY_KEY)
}
