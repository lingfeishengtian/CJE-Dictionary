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
/// Results are emitted in source order by exhausting each stream before moving to the next,
/// and deduplicated by SearchResultKey.
struct CombinedDictionaryStream: DictionaryStreamProtocol {
    private var streamStack: [DictionaryStreamProtocol]
    private var seenResults: Set<SearchResultKey> = []

    init(streams: [DictionaryStreamProtocol]) {
        self.streamStack = streams.reversed()
    }

    mutating func next() -> SearchResultKey? {
        guard !streamStack.isEmpty else {
            return nil
        }

        while !streamStack.isEmpty {
            var currentStream = streamStack.removeLast()
            if let nextKey = currentStream.next() {
                streamStack.append(currentStream)
                if seenResults.insert(nextKey).inserted {
                    return nextKey
                }
                continue
            }
            // exhausted stream is intentionally not pushed back onto stack
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
