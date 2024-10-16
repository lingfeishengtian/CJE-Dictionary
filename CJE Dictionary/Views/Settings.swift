//
//  Settings.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 8/5/24.
//

import SwiftUI

enum KanjiSettingsKeys: String {
    case showIconText = "kanjiSettingsShowIconText"
}

enum DictionaryStyleSettingsKeys: String {
    case ListStyleCondensed = "dictionaryStyleListStyleCondensed"
}

struct Settings: View {
    @StateObject var dictionaryManager = DictionaryManager(sessions: 1)
    @State var websiteURLString: String = ""
    @State var dictionaryName: String = ""
    @State var errorMessageKey: String = ""
    @State var showError: Bool = false
    @State var deleteAllDictionariesWarning = false
    
    @Environment(\.colorScheme) var colorScheme
    
    let additionalDictionaries = [
        "suupaadaijirin": "https://github.com/lingfeishengtian/CJE-Dictionary/raw/main/CJE%20Dictionary/Dictionaries/suupaadaijirin.zip"
    ]
    
    @inlinable
    func getBoolDefaultsKey(key: String) -> Bool {
        (UserDefaults.standard.value(forKey: key) as? Bool) ?? false
    }
    
    @inlinable
    func setDefaultsKey(key: String, val: Any) {
        UserDefaults.standard.set(val, forKey: key)
    }
    
    var body: some View {
        let additionalDictionariesUninstalled: [String] = additionalDictionaries.filter({ !dictionaryManager.getCurrentlyInstalledDictionaries(filterPreinstalled: true).contains($0.key) }).keys.uniqueElements
        return Form{
            Section() {
                VStack{
                    Group {
                        HStack{
                            Image(systemName: "arrow.down.to.line.circle.fill")
                            Text(LocalizedStringKey("Downloaded Dictionaries"))
                            Spacer()
                            Button (action: {
                                deleteAllDictionariesWarning = true
                            }, label: {
                                Image(systemName: "trash.fill")
                                    .foregroundStyle(.red)
                            }).buttonStyle(.plain)
                        }
                    }
                    Divider()
                    ForEach(dictionaryManager.getPreinstalledDictionaries(), id: \.self) { installedDict in
                        let isInstalled = dictionaryManager.doesDictionaryExist(dictName: installedDict)
                        HStack {
                            Text(installedDict)
                            Spacer()
                            Image(systemName: isInstalled ? "folder.fill" : "questionmark.folder")
                                .foregroundStyle(isInstalled ? .green : .red)
                        }
                    }
                    ForEach(dictionaryManager.getCurrentlyInstalledDictionaries(filterPreinstalled: true), id: \.self) { customDict in
                        HStack {
                            Text(customDict)
                            Spacer()
                            Image(systemName: "folder.circle")
                                .foregroundStyle(.yellow)
                        }
                    }
                    Divider().padding([.bottom], 5)
                    if additionalDictionariesUninstalled.count > 0 {
                        HStack{
                            Image(systemName: "book.fill")
                            Text(LocalizedStringKey("Available Dictionaries"))
                            Spacer()
                        }
                    }
                    ForEach(additionalDictionariesUninstalled, id: \.self) { additionalDictOption in
                        HStack {
                            Text(additionalDictOption)
                            Spacer()
                            Button(action: {
                                dictionaryManager.download(with: URL(string: additionalDictionaries[additionalDictOption]!)!, dictionaryName: additionalDictOption)
                            }, label: {
                                Image(systemName: "arrow.down.square")
                                    .foregroundStyle(dictionaryManager.progress != 0 && dictionaryManager.progress != 1.0 ? .gray : .green)
                                    .font(.title2)
                                    .buttonStyle(.plain)
                            })
                            .disabled(dictionaryManager.progress != 0 && dictionaryManager.progress != 1.0)
                        }.padding([.bottom], 5)
                    }
                    if additionalDictionariesUninstalled.count > 0 {
                        Divider().padding([.bottom], 5)
                    }
                    
                    HStack{
                        Image(systemName: "network")
                        Text(LocalizedStringKey("Install dictionary from the Web"))
                        Spacer()
                    }
                    HStack {
                        VStack {
                            TextField(LocalizedStringKey("Enter dictionary name"), text: $dictionaryName)
                                .foregroundStyle(.gray)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            TextField(LocalizedStringKey("Enter download link"), text: $websiteURLString)
                                    .foregroundStyle(.gray)
                        }
                        Button(LocalizedStringKey("Download")) {
                            if dictionaryName.count > 20 {
                                errorMessageKey = "Dictionary name too long"
                                showError = true
                            } else if dictionaryName.count == 0 {
                                errorMessageKey = "Dictionary name too short"
                                showError = true
                            } else if websiteURLString.count == 0 {
                                errorMessageKey = "Please enter website URL"
                                showError = true
                            } else if dictionaryName == ".DS_Store" || dictionaryManager.getCurrentlyInstalledDictionaries().contains(dictionaryName) {
                                errorMessageKey = "Dictionary name already exists"
                                showError = true
                            } else if (dictionaryManager.progress == 0 || dictionaryManager.progress == 1.0) {
                                if let url = URL(string: websiteURLString) {
                                    dictionaryManager.download(with: url, dictionaryName: dictionaryName)
                                } else {
                                    errorMessageKey = "Invalid website URL"
                                    showError = true
                                }
                            }
                        }.buttonStyle(.bordered)
                            .foregroundStyle(.white)
                            .background(dictionaryManager.progress == 0 || dictionaryManager.progress == 1.0 ? .blue : .gray)
                            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                    }
                    if dictionaryManager.progress > 0.0 {
                        ProgressView(value: dictionaryManager.progress, label: {
                            if (dictionaryManager.progress == 1.0 && !dictionaryManager.errorMessage.isEmpty) {
                                Text(dictionaryManager.errorMessage)
                                    .foregroundStyle(.red).lineLimit(1)
                            } else {
                                Text(dictionaryManager.progress == 1.0 ? String(localized: "Complete") :
                                        String(localized:"Downloading"))
                            }
                        })
                        .progressViewStyle(.linear)
                    }
                }
            } header: {
                Text(LocalizedStringKey("DOWNLOADS"))
            } footer: {
                Text(LocalizedStringKey("download_section_footer"))
            }
            
            Section() {
                HStack {
                    Toggle(isOn: Binding(get: {
                        getBoolDefaultsKey(key: KanjiSettingsKeys.showIconText.rawValue)
                    }, set: { val in
                        setDefaultsKey(key: KanjiSettingsKeys.showIconText.rawValue, val: val)
                    }), label: {
                        Text(LocalizedStringKey(KanjiSettingsKeys.showIconText.rawValue))
                    })
                }
            } header: {
                Text(LocalizedStringKey("KANJI DEFINITIONS"))
            }
            Section() {
                HStack {
                    Toggle(isOn: Binding(get: {
                        getBoolDefaultsKey(key: DictionaryStyleSettingsKeys.ListStyleCondensed.rawValue)
                    }, set: { val in
                        setDefaultsKey(key: DictionaryStyleSettingsKeys.ListStyleCondensed.rawValue, val: val)
                    }), label: {
                        Text(LocalizedStringKey(DictionaryStyleSettingsKeys.ListStyleCondensed.rawValue))
                    })
                }
            } header: {
                Text(LocalizedStringKey("DICTIONARY SEARCH"))
            }
        }.navigationTitle(LocalizedStringKey("settings"))
            .alert(LocalizedStringKey(errorMessageKey), isPresented: $showError) {
                Button(LocalizedStringKey("OK")) {}
            }
            .alert(LocalizedStringKey("deleteCustomDictWarn"), isPresented: $deleteAllDictionariesWarning) {
                Button(LocalizedStringKey("OK"), role: .destructive, action: {
                    dictionaryManager.deleteAllDictionaries()
                })
            }
    }
}

#Preview {
    Settings()
}
