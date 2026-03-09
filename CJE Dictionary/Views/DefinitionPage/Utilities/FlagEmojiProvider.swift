//
//  FlagEmojiProvider.swift
//  CJE Dictionary
//

import Foundation

struct FlagEmojiProvider {
    private static let languageToRegion: [String: String] = {
        var map: [String: String] = [:]
        for identifier in Locale.availableIdentifiers {
            let components = Locale.components(fromIdentifier: identifier)
            guard
                let language = components[NSLocale.Key.languageCode.rawValue]?.lowercased(),
                let region = components[NSLocale.Key.countryCode.rawValue]?.uppercased(),
                region.count == 2
            else {
                continue
            }
            if map[language] == nil {
                map[language] = region
            }
        }
        return map
    }()

    static func flagEmoji(for localeCode: String?) -> String {
        guard let rawCode = localeCode?.trimmingCharacters(in: .whitespacesAndNewlines), !rawCode.isEmpty else {
            return "🌐"
        }

        let normalized = rawCode.replacingOccurrences(of: "_", with: "-")
        let components = normalized.split(separator: "-").map(String.init)
        let isoRegions = Set(Locale.isoRegionCodes)

        let explicitRegion = components.last
            .map { $0.uppercased() }
            .flatMap { isoRegions.contains($0) ? $0 : nil }

        let directRegion = normalized.count == 2
            ? normalized.uppercased()
            : nil

        let languageCode = components.first?.lowercased() ?? normalized.lowercased()
        let inferredRegion = languageToRegion[languageCode]

        let regionCode = explicitRegion
            ?? (directRegion.flatMap { isoRegions.contains($0) ? $0 : nil })
            ?? inferredRegion

        guard let regionCode else {
            return "🌐"
        }

        return regionCode.unicodeScalars.reduce(into: "") { partialResult, scalar in
            guard let regional = UnicodeScalar(127397 + scalar.value) else { return }
            partialResult.unicodeScalars.append(regional)
        }
    }
}
