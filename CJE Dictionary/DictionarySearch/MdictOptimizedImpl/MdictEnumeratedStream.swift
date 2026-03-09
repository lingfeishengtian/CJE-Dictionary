//
//  MdictEnumeratedStream.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/5/26.
//

import Foundation
import mdict_tools

/// Efficient lazy stream for MdictOptimized prefix enumeration.
/// It fetches pages on demand and does not materialize full search results in memory.
struct MdictEnumeratedStream: DictionaryStreamProtocol {
	private let optimizedMdict: MdictOptimized
	private let dictionaryName: String
	private let prefix: String
	private let pageSize: UInt64
	private let exactMatch: String?
	private let includeReadings: Bool

	private var bufferedResults: [SearchResultKey] = []
	private var bufferIndex: Int = 0
	private var nextCursor: PrefixSearchCursor?
	private var hasRequestedFirstPage = false
	private var reachedEnd = false
	private var seenResults: Set<SearchResultKey> = []

	init(
		optimizedMdict: MdictOptimized,
		dictionaryName: String,
		prefix: String,
		pageSize: UInt64 = 100,
		exactMatch: String? = nil,
		includeReadings: Bool = true
	) {
		self.optimizedMdict = optimizedMdict
		self.dictionaryName = dictionaryName
		self.prefix = prefix
        self.pageSize = Swift.max(1, pageSize)
		self.exactMatch = exactMatch
		self.includeReadings = includeReadings
	}

	mutating func next() -> SearchResultKey? {
		while true {
			if bufferIndex < bufferedResults.count {
				let nextKey = bufferedResults[bufferIndex]
				bufferIndex += 1
				if seenResults.insert(nextKey).inserted {
					return nextKey
				}
				continue
			}

			guard loadNextPage() else {
				return nil
			}
		}
	}

	func toArray() -> [SearchResultKey] {
		var copy = self
		var output: [SearchResultKey] = []
		while let key = copy.next() {
			output.append(key)
		}
		return output
	}

	func map<T>(_ transform: (SearchResultKey) -> T) -> [T] {
		return toArray().map(transform)
	}

	func makeIterator() -> MdictEnumeratedStream {
		return self
	}

	private mutating func loadNextPage() -> Bool {
		if reachedEnd {
			return false
		}

		do {
			let page: PrefixSearchPage
			if !hasRequestedFirstPage {
				page = try optimizedMdict.setSearchPrefixPaged(prefix: prefix, pageSize: pageSize)
				hasRequestedFirstPage = true
			} else if let cursor = nextCursor {
				page = try optimizedMdict.prefixSearchNextPage(cursor: cursor)
			} else {
				reachedEnd = true
				return false
			}

			nextCursor = page.nextCursor
			bufferedResults = page.results.compactMap { keyBlock in
				if let exactMatch, keyBlock.keyText != exactMatch {
					return nil
				}

				let readings: [String]?
				if includeReadings {
					readings = try? optimizedMdict.getReadings(keyBlock: keyBlock)
				} else {
					readings = nil
				}

				return SearchResultKey(
					fromKeyBlock: keyBlock,
					dictionaryName: dictionaryName,
					readings: readings
				)
			}
			bufferIndex = 0

			if bufferedResults.isEmpty && nextCursor == nil {
				reachedEnd = true
				return false
			}

			return !bufferedResults.isEmpty || nextCursor != nil
		} catch {
			reachedEnd = true
			bufferedResults = []
			bufferIndex = 0
			print("Error loading MdictEnumeratedStream page for '\(prefix)': \(error)")
			return false
		}
	}
}
