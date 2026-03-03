//
//  DictionaryStream.swift
//  CJE Dictionary
//
//  Created by [Your Name] on [Date].
//

import Foundation

/// Protocol defining the interface for dictionary search result streams to support lazy evaluation and memory efficiency
protocol DictionaryStreamProtocol: Sequence, IteratorProtocol {
    /// Get the next key in the stream
    /// - Returns: Next SearchResultKey or nil if end of stream
    mutating func next() -> SearchResultKey?
    
    /// Get all keys in the stream (materializes the entire stream)
    /// - Returns: Array of all SearchResultKey objects
    func toArray() -> [SearchResultKey]
    
    /// Create a new stream with mapped results
    /// - Parameter transform: Closure that transforms each SearchResultKey
    /// - Returns: Array of transformed results
    func map<T>(_ transform: (SearchResultKey) -> T) -> [T]
}

/// Concrete implementation of DictionaryStreamProtocol for in-memory streaming
struct DictionaryStream: DictionaryStreamProtocol {
    private var keys: [SearchResultKey]
    private var currentIndex = 0
    
    init(keys: [SearchResultKey]) {
        self.keys = keys
    }
    
    /// Get the next key in the stream
    /// - Returns: Next SearchResultKey or nil if end of stream
    mutating func next() -> SearchResultKey? {
        guard currentIndex < keys.count else {
            return nil
        }
        let key = keys[currentIndex]
        currentIndex += 1
        return key
    }
    
    /// Get all keys in the stream (materializes the entire stream)
    /// - Returns: Array of all SearchResultKey objects
    func toArray() -> [SearchResultKey] {
        return keys
    }
    
    /// Add a key to the stream
    /// - Parameter key: SearchResultKey to add
    mutating func append(_ key: SearchResultKey) {
        keys.append(key)
    }
    
    /// Add multiple keys to the stream
    /// - Parameter newKeys: Array of SearchResultKey objects to add
    mutating func append(contentsOf newKeys: [SearchResultKey]) {
        keys.append(contentsOf: newKeys)
    }
    
    /// Reset the stream position to beginning
    mutating func reset() {
        currentIndex = 0
    }
    
    /// Create a new stream with mapped results
    /// - Parameter transform: Closure that transforms each SearchResultKey
    /// - Returns: Array of transformed results
    func map<T>(_ transform: (SearchResultKey) -> T) -> [T] {
        return keys.map(transform)
    }

    /// Conform to Sequence by returning the iterator (self)
    func makeIterator() -> DictionaryStream {
        return self
    }
}

/// Composite stream that merges multiple streams and yields results until all sources are exhausted.
/// Results are emitted in source-order round robin and deduplicated by SearchResultKey.
struct CombinedDictionaryStream: DictionaryStreamProtocol {
    private var streams: [DictionaryStreamProtocol]
    private var exhausted: [Bool]
    private var sourceIndex: Int = 0
    private var seenResults: Set<SearchResultKey> = []

    init(streams: [DictionaryStreamProtocol]) {
        self.streams = streams
        self.exhausted = Array(repeating: false, count: streams.count)
    }

    mutating func next() -> SearchResultKey? {
        guard !streams.isEmpty else {
            return nil
        }

        while exhausted.contains(false) {
            let currentIndex = sourceIndex
            sourceIndex = (sourceIndex + 1) % streams.count

            if exhausted[currentIndex] {
                continue
            }

            var currentStream = streams[currentIndex]
            if let nextKey = currentStream.next() {
                streams[currentIndex] = currentStream
                if seenResults.insert(nextKey).inserted {
                    return nextKey
                }
            } else {
                streams[currentIndex] = currentStream
                exhausted[currentIndex] = true
            }
        }

        return nil
    }

    func toArray() -> [SearchResultKey] {
        var copy = self
        var collected: [SearchResultKey] = []
        while let nextKey = copy.next() {
            collected.append(nextKey)
        }
        return collected
    }

    func map<T>(_ transform: (SearchResultKey) -> T) -> [T] {
        return toArray().map(transform)
    }

    func makeIterator() -> CombinedDictionaryStream {
        return self
    }
}
