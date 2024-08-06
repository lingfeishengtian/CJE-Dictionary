//
//  KanjiDefinition.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 8/4/24.
//

import SwiftUI

struct KanjiDefinition: View {
    let kanjiInfo: KanjiInfo
    
    var body: some View {
        let _ = print(kanjiInfo.description)
        VStack (alignment: .leading) {
            HStack {
                Text(String(kanjiInfo.kanjiCharacter))
                    .bold()
                    .font(Font.custom("HiraMinProN-W3", size: 120))
                VStack  (alignment:.leading){
                    if let onReadings = kanjiInfo.readings["ja_on"] {
                        HStack (alignment: .top){
                            Label(
                                // TODO: Create icon 音
                                title: { Text(String(localized: "ja_on")) },
                                icon: { /*@START_MENU_TOKEN@*/Image(systemName: "42.circle")/*@END_MENU_TOKEN@*/ }
                            )
                            Text(onReadings.joined(separator: ", "))
                        }
                    }
                    
                    if let kunReadings = kanjiInfo.readings["ja_kun"] {
                        HStack (alignment: .top){
                            Label(
                                // TODO: Create icon 音
                                title: { Text(String(localized: "ja_kun")) },
                                icon: { /*@START_MENU_TOKEN@*/Image(systemName: "42.circle")/*@END_MENU_TOKEN@*/ }
                            )
                            Text(kunReadings.joined(separator: ", "))
                        }
                    }
                    
                    if let nanoriReadings = kanjiInfo.readings["nanori"], nanoriReadings.count > 0 {
                        HStack (alignment: .top){
                            Label(
                                // TODO: Create icon 音
                                title: { Text(String(localized: "nanori")) },
                                icon: { /*@START_MENU_TOKEN@*/Image(systemName: "42.circle")/*@END_MENU_TOKEN@*/ }
                            )
                            Text(nanoriReadings.joined(separator: ", "))
                        }
                    }
                    
                    if let pinyin = kanjiInfo.readings["pinyin"] {
                        HStack (alignment: .top){
                            Label(
                                // TODO: Create icon 音
                                title: { Text(String(localized: "pinyin")) },
                                icon: { /*@START_MENU_TOKEN@*/Image(systemName: "42.circle")/*@END_MENU_TOKEN@*/ }
                            )
                            Text(pinyin.joined(separator: ", "))
                        }
                    }
                }
                Spacer()
            }.padding([.leading, .trailing], 20)
                .padding([.bottom], 5)
            if !kanjiInfo.meaning.isEmpty {
                VStack(alignment: .leading) {
                    Text(String(localized: "Meanings")).font(.headline)
                    HStack {
                        Text(kanjiInfo.meaning.joined(separator: ", "))
                    }
                }.padding([.leading, .trailing], 25)
                    .padding([.bottom], 5)
            }
            if let hanzi = convertKanjiToHanzi(character: kanjiInfo.kanjiCharacter) {
                HStack {
                    Text(String(localized: "Simplified Chinese Form ")).font(.headline)
                    Text(String(hanzi))
                        .bold()
                }.padding([.leading, .trailing], 25)
                    .padding([.bottom], 5)
            }
            if (kanjiInfo.strokeCount != nil) {
                HStack {
                    Text(String(localized: "Stroke Counts ")).font(.headline)
                    Text(String(kanjiInfo.strokeCount!))
                }.padding([.leading, .trailing], 25)
                    .padding([.bottom], 5)
            }
            VStack(alignment: .leading) {
                Text(String(localized: "Miscellaneous ")).font(.headline)
                HStack {
                    if let jlpt = kanjiInfo.jlpt {
                        Text(String(localized: "JLPT Level"))
                        Text(String(jlpt))
                    }
                }
                HStack {
                    if let grade = kanjiInfo.grade {
                        Text(String(localized: "Grade Level"))
                        Text(String(grade))
                    }
                }
                HStack {
                    if let frequency = kanjiInfo.frequency {
                        Text(String(localized: "Frequency"))
                        Text(String(frequency))
                    }
                }
            }.padding([.leading, .trailing], 25)
                .padding([.bottom], 5)
            
            Spacer()
        }
    }
}

#Preview {
    KanjiDefinition(kanjiInfo: KanjiInfo(kanjiCharacter: "雲", jlpt: 2, grade: 2, frequency: 1256, readings: [
        "ja_on": ["ウン"],
        "ja_kun": ["くも", "-ぐも"],
        "pinyin": ["yun2"],
        "nanori": ["き", "ずも", "のめ"]
    ], strokeCount: 12, meaning: ["cloud"]))
}
