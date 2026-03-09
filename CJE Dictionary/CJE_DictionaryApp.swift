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
            AppView()
        }
    }
}

struct AppView: View {
    @State var selectedMenu: String? = "dictionary"
    @State private var dictionaryReloadToken = UUID()
    @State private var migrationNotice: AppMigrationNotice?
    @State private var hasCheckedMigration = false
    let menus = [
        "dictionary",
        "settings"
    ]

    var body: some View {
        Group {
#if os(macOS)
            NavigationSplitView {
                List(menus, id: \.self, selection: $selectedMenu) { menu in
                    Text(LocalizedStringKey(menu))
                }
                .navigationTitle(String(localized: "CJE Dictionary"))
            } detail: {
                switch selectedMenu {
                case menus[0]:
                    dictionaryRootView
                case menus[1]:
                    Settings()
                default:
                    EmptyView()
                }
            }
        
#else
            TabView {
                dictionaryRootView
                    .tabItem {
                        Label("dictionary", systemImage: "book")
                    }

                Settings()
                    .tabItem {
                        Label("settings", systemImage: "gearshape")
                    }
            }
#endif
        }
            .onReceive(NotificationCenter.default.publisher(for: .dictionaryCatalogDidChange)) { _ in
                dictionaryReloadToken = UUID()
            }
            .onAppear {
                guard !hasCheckedMigration else { return }
                hasCheckedMigration = true
                migrationNotice = V1ToV2MigrationUtility.runIfNeeded()
            }
            .alert(item: $migrationNotice) { notice in
                Alert(
                    title: Text(notice.title),
                    message: Text(notice.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }

    @ViewBuilder
    private var dictionaryRootView: some View {
        let dictionaries = createAvailableDictionaries()

        if !dictionaries.isEmpty {
            SearchDictionaryListView(dictionaries: dictionaries)
                .id(dictionaryReloadToken)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("You have no dictionaries downloaded")
                    .font(.headline)

                Text("Go to Settings to download a dictionary.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

#Preview {
    ProgressView(value: 0.5)
    {
        Text(String(localized: "Please wait for app resources to unload, this will take a little bit of time on the first app launch."))
            .multilineTextAlignment(.center)
    }
    .progressViewStyle(.linear)
    .padding()
}

extension UserDefaults {
    static let group = UserDefaults(suiteName: "group.com.hunterhan")
}
