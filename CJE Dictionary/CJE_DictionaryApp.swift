//
//  CJE_DictionaryApp.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/30/23.
//

import SwiftUI

@main
struct CJE_DictionaryApp: App {
    @State private var progress: Double = 0.0
    
    var body: some Scene {
        WindowGroup {
            if progress < 1.0 {
                
                ProgressView("Please wait for app resources to unload, this will take a little bit of time on the first app launch.")
                    .progressViewStyle(.circular)
                    .padding()
                    .task {
                        createDictionaryIfNotPresent()
                        progress = 1.0
                    }
            } else {
                ContentView()
            }
        }
    }
}

extension UserDefaults {
    static let group = UserDefaults(suiteName: "group.com.hunterhan")
}
