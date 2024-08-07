//
//  KanjiDefinition.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 8/4/24.
//

import SwiftUI

struct ExtractedView: View {
    let shouldShowText: Bool = (UserDefaults.standard.value(forKey: KanjiSettingsKeys.showIconText.rawValue) as? Bool) ?? false
    let iconChar: Character
    let readings: [String]
    let iconText: String.LocalizationValue
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack (alignment: .top){
            Text(String(iconChar))
                .padding(4)
                .background(colorScheme == .dark ? .blue : .yellow)
                .clipShape(Circle())
            if shouldShowText {
                Text(String(localized: iconText)).padding([.top, .bottom], 4)
            }
            Text(readings.joined(separator: ", ")).padding(4)
        }
    }
}

struct KanjiDefinition: View {
    let kanjiInfo: KanjiInfo
    
    var body: some View {
        VStack (alignment: .leading) {
            HStack {
                Text(String(kanjiInfo.kanjiCharacter))
                    .bold()
                    .font(Font.custom("HiraMinProN-W3", size: 120))
                VStack  (alignment:.leading, spacing: 2){
                    if let onReadings = kanjiInfo.readings["ja_on"] {
                        ExtractedView(iconChar: "音", readings: onReadings, iconText: "ja_on")
                    }
                    
                    if let kunReadings = kanjiInfo.readings["ja_kun"] {
                        ExtractedView(iconChar: "訓", readings: kunReadings, iconText: "ja_kun")
                    }
                    
                    if let nanoriReadings = kanjiInfo.readings["nanori"], nanoriReadings.count > 0 {
                        ExtractedView(iconChar: "名", readings: nanoriReadings, iconText: "nanori")
                    }
                    
                    if let pinyin = kanjiInfo.readings["pinyin"] {
                        ExtractedView(iconChar: "拼", readings: pinyin, iconText: "pinyin")
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
