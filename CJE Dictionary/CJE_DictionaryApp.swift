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
            InitialView()
        }
    }
}

struct InitialView : View {
    @StateObject var dictionaryManager: DictionaryManager = DictionaryManager(sessions: 3)
    
    var body: some View {
        if dictionaryManager.progress < 1.0 {
            ProgressView(value: dictionaryManager.progress)
            {
                HStack {
                    Spacer()
                    Text(String(localized: "Please wait for app resources to unload, this will take a little bit of time on the first app launch."))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }.progressViewStyle(.linear)
                .padding()
                .onAppear() {
                    Task.init {
                        await dictionaryManager.downloadAllAvailableLinks()
                    }
                }
        } else {
            AppView()
        }
    }
}

struct AppView: View {
    @State var selectedMenu: String? = "dictionary"
    let menus = [
        "dictionary",
        "settings"
    ]
    
    var body: some View {
        NavigationSplitView {
            List(menus, id: \.self, selection: $selectedMenu) { menu in
                Text(LocalizedStringKey(menu))
            }
            .navigationTitle(String(localized: "CJE Dictionary"))
        } detail: {
            switch selectedMenu {
            case menus[0]:
                DictionarySearchView()
            case menus[1]:
                Settings()
            default:
                DictionarySearchView()
            }
        }
    }
}

#Preview {
    ProgressView(value: 0.5)
    {
        Text(String(localized: "Please wait for app resources to unload, this will take a little bit of time on the first app launch."))
            .multilineTextAlignment(.center)
    }.progressViewStyle(.linear)
        .padding()
        .onAppear() {
            
        }
}

extension UserDefaults {
    static let group = UserDefaults(suiteName: "group.com.hunterhan")
}
