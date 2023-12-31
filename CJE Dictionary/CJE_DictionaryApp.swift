//
//  CJE_DictionaryApp.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/30/23.
//

import SwiftUI

@main
struct CJE_DictionaryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

extension UserDefaults {
    static let group = UserDefaults(suiteName: "group.com.hunterhan")
}
