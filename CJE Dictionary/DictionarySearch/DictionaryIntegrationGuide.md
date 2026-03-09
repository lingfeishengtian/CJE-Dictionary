//
//  DictionaryIntegrationGuide.md
//  CJE Dictionary
//

# Dictionary Protocol Integration Guide

This document explains how to integrate MdictOptimized dictionaries into the existing CJE Dictionary system.

## Overview

The implementation introduces a protocol-based approach that allows different dictionary formats (SQLite, MongoDB, MdictOptimized) to be used interchangeably while maintaining consistent interfaces.

For metadata-first loading and manifest design, see [docs/dictionary_metadata_spec.md](../../docs/dictionary_metadata_spec.md).

For Script.js parser requirements, see [ScriptJSContract.md](./ScriptJSContract.md).

## Key Components

### 1. DictionaryProtocol.swift
Defines the common interface for all dictionary implementations:
- Search operations (exact match, prefix search)
- Word retrieval by ID
- Pagination support
- Metadata about dictionaries

### 2. MdictOptimizedDictionary.swift
Implements the protocol specifically for MdictOptimized format using the mdict_tools Swift library.

### 3. MdictOptimizedManager.swift
Manages creation and caching of MdictOptimized instances:
- Creates optimized dictionaries from bundles (MDX/MDD files)
- Supports progress callbacks for long-running builds
- Caches created instances to avoid re-creating them

## Integration Points

To use MdictOptimized dictionaries in the search system:

1. **Create an MdictOptimized instance** using `MdictOptimizedManager.createOptimized(...)`
2. **Wrap it in a DictionaryProtocol** by creating an `MdictOptimizedDictionary` instance
3. **Use it in search operations** through the common interface

## Usage Example

```swift
// Create MdictOptimized dictionary
let optimized = MdictOptimizedManager.createOptimized(
    fromBundle: bundlePath,
    fstPath: fstPath,
    readingsPath: readingsPath,
    recordPath: recordPath
)

if let optimizedDict = optimized {
    // Wrap in protocol
    let dict = MdictOptimizedDictionary(
        name: "MyMdict",
        type: LanguageToLanguage(searchLanguage: .JP, resultsLanguage: .EN),
        optimizedMdict: optimizedDict
    )
    
    // Use through common interface
    let results = dict.searchExact("word")
}
```

## Implementation Notes

- The existing SQLite-based dictionaries continue to work unchanged
- MdictOptimized dictionaries are added as a new supported type
- All dictionary operations are consistent through the DictionaryProtocol interface
- Backward compatibility is maintained
