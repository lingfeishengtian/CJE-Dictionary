//
//  MongoEnumeratedStream.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/6/26.
//

import Foundation
import RealmSwift

struct MongoEnumeratedStream: DictionaryStreamProtocol {
	private let dictionaryName: String
	private var legacyResultSets: [Results<Wort>] = []
	private var indexResultSets: [Results<MongoWordIndexObject>] = []

	private var legacySetIndex: Int = 0
	private var legacyItemIndex: Int = 0
	private var indexSetIndex: Int = 0
	private var indexItemIndex: Int = 0

	private var seenLegacyObjectIds: Set<String> = []
	private var seenIndexIds: Set<Int64> = []

	init(dictionaryName: String, realmPath: String, query: String, exactMatch: Bool) {
		self.dictionaryName = dictionaryName

		do {
			let configuration = mongoRealmConfiguration(filePath: realmPath)
			let openedRealm = try Realm(configuration: configuration)
			self.legacyResultSets = Self.legacyResultSets(in: openedRealm, query: query, exactMatch: exactMatch)
				.map { $0.freeze() }
			self.indexResultSets = Self.indexResultSets(in: openedRealm, query: query, exactMatch: exactMatch)
				.map { $0.freeze() }
		} catch {
			self.legacyResultSets = []
			self.indexResultSets = []
			print("MongoEnumeratedStream init error: \(error)")
		}
	}

	mutating func next() -> SearchResultKey? {
		while legacySetIndex < legacyResultSets.count {
			let currentSet = legacyResultSets[legacySetIndex]
			while legacyItemIndex < currentSet.count {
				let wort = currentSet[legacyItemIndex]
				legacyItemIndex += 1

				if let key = keyFromLegacyWort(wort) {
					return key
				}
			}

			legacySetIndex += 1
			legacyItemIndex = 0
		}

		while indexSetIndex < indexResultSets.count {
			let currentSet = indexResultSets[indexSetIndex]
			while indexItemIndex < currentSet.count {
				let object = currentSet[indexItemIndex]
				indexItemIndex += 1

				if !seenIndexIds.insert(object.id).inserted {
					continue
				}

				let keyText = object.wort ?? ""
				let readingsText = object.w ?? ""

				return SearchResultKey(
					id: String(object.id),
					dictionaryName: dictionaryName,
					keyText: keyText,
					keyId: object.id,
					readings: Self.parseReadings(readingsText)
				)
			}

			indexSetIndex += 1
			indexItemIndex = 0
		}

		return nil
	}

	func toArray() -> [SearchResultKey] {
		var copy = self
		var output: [SearchResultKey] = []
		while let item = copy.next() {
			output.append(item)
		}
		return output
	}

	func map<T>(_ transform: (SearchResultKey) -> T) -> [T] {
		return toArray().map(transform)
	}

	func makeIterator() -> MongoEnumeratedStream {
		return self
	}

	private static func parseReadings(_ readings: String) -> [String] {
		return readings
			.split(separator: "|")
			.map { String($0) }
			.map { value in
				value.hasPrefix("┏") ? String(value.dropFirst()) : value
			}
			.filter { !($0.contains("【") && $0.contains("】")) }
	}

	private mutating func keyFromLegacyWort(_ wort: Wort) -> SearchResultKey? {
		let objectId = wort.objectId ?? ""
		if !objectId.isEmpty {
			guard seenLegacyObjectIds.insert(objectId).inserted else { return nil }
		}

		let keyText = wort.spell ?? wort.pron ?? ""
		let reading = wort.pron?.trimmingCharacters(in: .whitespacesAndNewlines)
		let readings = (reading?.isEmpty == false) ? [reading!] : nil

		let idString = objectId.isEmpty ? keyText : objectId
		let keyId = Self.stableKeyId(for: idString)

		return SearchResultKey(
			id: idString,
			dictionaryName: dictionaryName,
			keyText: keyText,
			keyId: keyId,
			readings: readings
		)
	}

	private static func indexResultSets(in realm: Realm, query: String, exactMatch: Bool) -> [Results<MongoWordIndexObject>] {
		let base = realm.objects(MongoWordIndexObject.self)

		if exactMatch {
			return [base.filter("wort == %@ OR w == %@", query, query)]
		}

		return [
			base.filter("wort BEGINSWITH[c] %@ OR w BEGINSWITH[c] %@", query, query)
		]
	}

	private static func legacyResultSets(in realm: Realm, query: String, exactMatch: Bool) -> [Results<Wort>] {
		if exactMatch {
			return [realm.objects(Wort.self)
				.filter("spell == %@ OR pron == %@", query, query)]
		}

		return [realm.objects(Wort.self)
			.filter("spell BEGINSWITH[c] %@ OR pron BEGINSWITH[c] %@", query, query)]
	}

	private static func stableKeyId(for value: String) -> Int64 {
		Int64(bitPattern: UInt64(truncatingIfNeeded: value.hashValue))
	}
}
