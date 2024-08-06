//
//  CJE_DictionaryApp.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/30/23.
//

import SwiftUI
import Network

@main
struct CJE_DictionaryApp: App {
    
    var body: some Scene {
        WindowGroup {
            InitialView()
        }
    }
}

class NetworkMonitor: ObservableObject {
    @Published var connected: Bool = false
    let monitor: NWPathMonitor
    var startedDownloads = false
    
    init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self.connected = true
                } else {
                    self.connected = false
                }
            }
            
            print(path.isExpensive)
        }
        
        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
    }
}

struct InitialView : View {
    @StateObject var dictionaryManager: DictionaryManager = DictionaryManager(sessions: 3)
    @StateObject var networkMonitor = NetworkMonitor()
    
    var body: some View {
        let _ = Task.init {
            if (!networkMonitor.connected && dictionaryManager.getCurrentlyInstalledDictionaries().count == 0) || (networkMonitor.startedDownloads) {
                return
            }
            await dictionaryManager.downloadAllAvailableLinks()
            networkMonitor.startedDownloads = true
        }
        
        if dictionaryManager.progress < 1.0 || (!networkMonitor.connected && dictionaryManager.getCurrentlyInstalledDictionaries().count == 0) {
            ProgressView(value: dictionaryManager.progress)
            {
                
                HStack {
                    Spacer()
                    let _ = print(networkMonitor.connected)
                    if !networkMonitor.connected {
                        Text(String(localized: "no_internet_connection"))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
                HStack {
                    Spacer()
                    Text(String(localized: "Please wait for app resources to unload, this will take a little bit of time on the first app launch."))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }.progressViewStyle(.linear)
                .padding()
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
