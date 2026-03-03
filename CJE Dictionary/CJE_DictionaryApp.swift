//
//  CJE_DictionaryApp.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 12/30/23.
//

import SwiftUI
import Network


struct MockDict: DictionaryProtocol {
    var name: String = "Mock"
    var type: LanguageToLanguage = LanguageToLanguage(searchLanguage: .JP, resultsLanguage: .EN)
    func searchExact(_ searchString: String) -> DictionaryStreamProtocol { DictionaryStream(keys: [SearchResultKey(id: "1", dictionaryName: "mock", keyText: searchString, keyId: 1)]) }
    func searchPrefix(_ prefix: String) -> DictionaryStreamProtocol {
        // Try to initialize MdictOptimized from bundle FST/rd/def files (jitendex.*)
        // Try bundle first, then look in repository root (useful for previews)
        var fstPath: String? = Bundle.main.path(forResource: "jitendex", ofType: "fst")
        var rdPath: String? = Bundle.main.path(forResource: "jitendex", ofType: "rd")
        var defPath: String? = Bundle.main.path(forResource: "jitendex", ofType: "def")
        if fstPath == nil || rdPath == nil || defPath == nil {
            if let src = ProcessInfo.processInfo.environment["SRCROOT"] {
                let base = URL(fileURLWithPath: src).appendingPathComponent("Resources")
                let tryFst = base.appendingPathComponent("jitendex.fst").path
                let tryRd = base.appendingPathComponent("jitendex.rd").path
                let tryDef = base.appendingPathComponent("jitendex.def").path
                if FileManager.default.fileExists(atPath: tryFst) && FileManager.default.fileExists(atPath: tryRd) && FileManager.default.fileExists(atPath: tryDef) {
                    fstPath = tryFst
                    rdPath = tryRd
                    defPath = tryDef
                }
            }
        }

        if let fst = fstPath, let rd = rdPath, let def = defPath {
            if let optimized = MdictOptimizedManager.createOptimized(fromBundle: "", fstPath: fst, readingsPath: rd, recordPath: def) {
                let dict = MdictOptimizedDictionary(name: "jitendex", type: type, optimizedMdict: optimized)
                return dict.searchPrefix(prefix)
            }
        }

        // fallback: generate 200 sample SearchResultKey objects for preview/testing
        let keys: [SearchResultKey] = (0..<200).map { i in
            SearchResultKey(id: "\(i)", dictionaryName: "mock", keyText: "\(prefix)-\(i)", keyId: Int64(i), readings: (i % 5 == 0) ? ["r\(i)"] : nil)
        }
        return DictionaryStream(keys: keys)
    }
    func getWord(byId id: AnyHashable) -> Word? { Word(id: String(describing: id), dict: .jitendex, word: "Word \(id)", readings: ["r1"]) }
    func getWord(fromKey key: SearchResultKey) -> Word? { Word(id: key.id, dict: .jitendex, word: key.keyText, readings: key.readings ?? []) }
}

@main
struct CJE_DictionaryApp: App {
    
    var body: some Scene {
        WindowGroup {
//            InitialView()
            SearchDictionaryListView(dictionary: MockDict())
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
            let _ = networkMonitor.monitor.cancel()
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
