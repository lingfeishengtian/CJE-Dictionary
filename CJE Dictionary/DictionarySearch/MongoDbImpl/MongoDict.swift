//
//  MongoDict.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/6/26.
//

import Foundation
import RealmSwift

enum MongoDefinitionParseError: LocalizedError {
	case missingRecordData
	case decodingFailed
	case missingScript(String)
	case invalidScriptResult
	case missingRealm(String)

	var errorDescription: String? {
		switch self {
		case .missingRecordData:
			return "No definition record data was found for this key."
		case .decodingFailed:
			return "Unable to decode definition content from record data."
		case .missingScript(let path):
			return "Script.js not found at path: \(path)"
		case .invalidScriptResult:
			return "Script.js returned an invalid result payload."
		case .missingRealm(let path):
			return "Realm connection missing for \(path)."
		}
	}
}


struct MongoDict: DictionaryProtocol {
	let name: String
	let dictionaryType: DictionaryTypeDescriptor
	private let databasePath: String
	private let scriptPath: String?

	init(name: String, type: LanguageToLanguage, databasePath: String, scriptPath: String? = nil) {
		self.name = name
		self.dictionaryType = type.asDescriptor(
			id: name,
			displayName: name,
			backend: .unknown,
			parser: .scriptJS
		)
		self.databasePath = databasePath
		self.scriptPath = scriptPath
	}

	init(name: String, dictionaryType: DictionaryTypeDescriptor, databasePath: String, scriptPath: String? = nil) {
		self.name = name
		self.dictionaryType = dictionaryType
		self.databasePath = databasePath
		self.scriptPath = scriptPath
	}

	init?(
		name: String,
		type: LanguageToLanguage,
		databaseFileName: String,
		databaseDirectory: String? = nil,
		scriptFileName: String = "Script.js",
		bundle: Bundle = .main
	) {
		guard let resolvedDatabasePath = Self.resolveDatabasePath(
			fileName: databaseFileName,
			inDirectory: databaseDirectory,
			bundle: bundle
		) else {
			return nil
		}

		let resolvedScriptPath = Self.resolvePath(fileName: scriptFileName, inDirectory: databaseDirectory, bundle: bundle)
			?? Self.resolvePath(fileName: scriptFileName, bundle: bundle)

		self.init(name: name, type: type, databasePath: resolvedDatabasePath, scriptPath: resolvedScriptPath)
	}

	func searchExact(_ searchString: String) -> DictionaryStreamProtocol {
		return MongoEnumeratedStream(
			dictionaryName: name,
			realmPath: databasePath,
			query: searchString,
			exactMatch: true
		)
	}

	func searchPrefix(_ prefix: String) -> DictionaryStreamProtocol {
		return MongoEnumeratedStream(
			dictionaryName: name,
			realmPath: databasePath,
			query: prefix,
			exactMatch: false
		)
	}

	func getWord(byId id: AnyHashable) -> Word? {
		guard let idValue = Self.idFromAnyHashable(id),
			  let object = Self.rowForId(idValue, realmPath: databasePath)
		else {
			return nil
		}

		let word = object.wort ?? ""
		let readings = Self.parseReadings(object.w ?? "")
		return Word(id: String(idValue), dictionaryName: name, word: word, readings: readings)
	}

	func getWord(fromKey key: SearchResultKey) -> Word? {
		if getRecordData(fromKey: key) != nil {
			return Word(
				id: key.id,
				dictionaryName: name,
				word: key.keyText,
				readings: key.readings ?? []
			)
		}
		return nil
	}

	func getRecordData(fromKey key: SearchResultKey) -> Data? {
		guard let realm = Self.openRealm(at: databasePath) else {
			return nil
		}

		if let object = Self.rowForKey(key, in: realm) ?? Self.rowForId(key.keyId, in: realm),
		   let recordText = object.m ?? Self.recordTextForWordObject(id: key.keyId, in: realm) {
			return recordText.data(using: .utf8)
		}

		return nil
	}

	func getDefinitionGroups(fromKey key: SearchResultKey) async throws -> [DefinitionGroup] {
		if let legacyGroups = legacyDefinitionGroups(fromKey: key), !legacyGroups.isEmpty {
			return legacyGroups
		}

		guard let recordData = getRecordData(fromKey: key) else {
			throw MongoDefinitionParseError.missingRecordData
		}

		guard let html = String(data: recordData, encoding: .utf8)
			?? String(data: recordData, encoding: .utf16)
			?? String(data: recordData, encoding: .unicode),
			!html.isEmpty
		else {
			throw MongoDefinitionParseError.decodingFailed
		}

		guard let scriptPath = scriptPath else {
			throw MongoDefinitionParseError.missingScript("Bundle.main")
		}

		let script = try String(contentsOfFile: scriptPath, encoding: .utf8)
		return try await ScriptExecutor.execute(html: html, script: script)
	}

	private static func rowForId(_ id: Int64, realmPath: String) -> MongoWordIndexObject? {
		guard let realm = openRealm(at: realmPath) else { return nil }
		return rowForId(id, in: realm)
	}

	private static func resolvePath(fileName: String, bundle: Bundle) -> String? {
		let fileURL = URL(fileURLWithPath: fileName)
		let baseName = fileURL.deletingPathExtension().lastPathComponent
		let fileExtension = fileURL.pathExtension.isEmpty ? nil : fileURL.pathExtension
		if let path = bundle.path(forResource: baseName, ofType: fileExtension) {
			return path
		}
		return nil
	}

	private static func resolvePath(fileName: String, inDirectory directory: String?, bundle: Bundle) -> String? {
		guard let directory else {
			return nil
		}

		let fileURL = URL(fileURLWithPath: fileName)
		let baseName = fileURL.deletingPathExtension().lastPathComponent
		let fileExtension = fileURL.pathExtension.isEmpty ? nil : fileURL.pathExtension
		if let path = bundle.path(forResource: baseName, ofType: fileExtension, inDirectory: directory) {
			return path
		}
		return nil
	}

	private static func resolveDatabasePath(fileName: String, inDirectory directory: String?, bundle: Bundle) -> String? {
		if let inBundlePath = resolvePath(fileName: fileName, inDirectory: directory, bundle: bundle)
			?? resolvePath(fileName: fileName, bundle: bundle) {
			return inBundlePath
		}

		let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		if let directory {
			let inDirectory = documents.appendingPathComponent(directory).appendingPathComponent(fileName).path
			if FileManager.default.fileExists(atPath: inDirectory) {
				return inDirectory
			}
		}

		let rootPath = documents.appendingPathComponent(fileName).path
		if FileManager.default.fileExists(atPath: rootPath) {
			return rootPath
		}

		return nil
	}

	private static func openRealm(at path: String) -> Realm? {
		do {
			let configuration = mongoRealmConfiguration(filePath: path)
			return try Realm(configuration: configuration)
		} catch {
			print("MongoDict openRealm error (\(path)): \(error)")
			return nil
		}
	}

	private static func rowForKey(_ key: SearchResultKey, in realm: Realm) -> MongoWordIndexObject? {
		realm.objects(MongoWordIndexObject.self)
			.where {
				$0.id == key.keyId && $0.wort == key.keyText
			}
			.first
	}

	private static func rowForId(_ id: Int64, in realm: Realm) -> MongoWordIndexObject? {
		realm.objects(MongoWordIndexObject.self)
			.where {
				$0.id == id
			}
			.first
	}

	private static func idFromAnyHashable(_ id: AnyHashable) -> Int64? {
		if let intId = id.base as? Int { return Int64(intId) }
		if let int64Id = id.base as? Int64 { return int64Id }
		if let stringId = id.base as? String, let parsed = Int64(stringId) { return parsed }
		return nil
	}

	private static func recordTextForWordObject(id: Int64, in realm: Realm) -> String? {
		realm.objects(MongoWordObject.self)
			.where {
				$0.id == id
			}
			.first?
			.m
	}

	private static func parseReadings(_ readings: String) -> [String] {
		readings
			.split(separator: "|")
			.map(String.init)
			.map { value in
				value.hasPrefix("┏") ? String(value.dropFirst()) : value
			}
			.filter { !($0.contains("【") && $0.contains("】")) }
	}

	private func legacyDefinitionGroups(fromKey key: SearchResultKey) -> [DefinitionGroup]? {
		guard let realm = Self.openRealm(at: databasePath) else {
			return nil
		}

		guard let wort = Self.findLegacyWort(for: key, in: realm) else {
			return nil
		}

		let details = realm.objects(Details.self)
			.where {
				$0.wordId == wort.objectId && $0.title != nil && $0.title != ""
			}
			.sorted(byKeyPath: "index", ascending: true)

		let tags = details.map {
			Tag(shortName: $0.title ?? "", longName: $0.title ?? "")
		}

		let subdetails = realm.objects(Subdetails.self)
			.where { $0.wordId == wort.objectId }
			.sorted(byKeyPath: "index", ascending: true)

		let definitions: [Definition] = subdetails.map { subdetail in
			let examples = realm.objects(Example.self)
				.where { $0.subdetailsId == subdetail.objectId }
				.sorted(byKeyPath: "index", ascending: true)

			let sentences: [ExampleSentence] = examples.flatMap { example in
				var output: [ExampleSentence] = []
				if let jp = example.title, !jp.isEmpty {
					output.append(ExampleSentence(language: Language(rawValue: "ja-JP"), attributedString: AttributedString(jp)))
				}
				if let cn = example.trans, !cn.isEmpty {
					output.append(ExampleSentence(language: Language(rawValue: "zh-CN"), attributedString: AttributedString(cn)))
				}
				return output
			}

			return Definition(
				definition: subdetail.title ?? "",
				exampleSentences: sentences
			)
		}

		if definitions.isEmpty {
			return nil
		}

		return [DefinitionGroup(tags: Array(tags), definitions: definitions)]
	}

	private static func findLegacyWort(for key: SearchResultKey, in realm: Realm) -> Wort? {
		if let byObjectId = realm.objects(Wort.self)
			.where({ $0.objectId == key.id })
			.first {
			return byObjectId
		}

		if let bySpell = realm.objects(Wort.self)
			.where({ $0.spell == key.keyText })
			.first {
			return bySpell
		}

		if let reading = key.readings?.first,
		   let byPron = realm.objects(Wort.self)
			.where({ $0.pron == reading })
			.first {
			return byPron
		}

		return nil
	}
}
