//
//  MdictOptimizedManager.swift
//  CJE Dictionary
//
//  Created by [Your Name] on [Date].
//

import Foundation
import mdict_tools

/// Manager for handling MdictOptimized dictionaries
class MdictOptimizedManager {
    /// Cache of initialized MdictOptimized instances
    private static var optimizedDictionaries: [String: MdictOptimized] = [:]
    
    /// Create and cache an MdictOptimized instance from a bundle
    /// - Parameters:
    ///   - bundlePath: Path to the MDX file
    ///   - mddPath: Path to the MDD file (optional)
    ///   - fstPath: Path for FST index file
    ///   - readingsPath: Path for readings file
    ///   - recordPath: Path for record data file
    /// - Returns: Initialized MdictOptimized instance or nil on error
    static func createOptimized(fromBundle bundlePath: String, 
                               mddPath: String? = nil,
                               fstPath: String,
                               readingsPath: String,
                               recordPath: String) -> MdictOptimized? {
        do {
            // First try to create from FST if it exists
            if FileManager.default.fileExists(atPath: fstPath) {
                return try createMdictOptimizedFromFst(
                    fstPath: fstPath,
                    readingsPath: readingsPath,
                    recordPath: recordPath
                )
            } else {
                // Create from bundle if FST doesn't exist yet
                let bundle = try createMdictBundle(mdxPath: bundlePath, mddPath: mddPath ?? "")
                let optimized = try createMdictOptimizedFromBundle(
                    bundle: bundle,
                    fstPath: fstPath,
                    readingsPath: readingsPath,
                    recordPath: recordPath
                )
                
                // Cache the optimized instance
                let key = "\(bundlePath)_\(mddPath ?? "")"
                optimizedDictionaries[key] = optimized
                
                return optimized
            }
        } catch {
            print("Error creating MdictOptimized from bundle: \(error)")
            return nil
        }
    }
    
    /// Create and cache an MdictOptimized instance with progress callback
    /// - Parameters:
    ///   - bundlePath: Path to the MDX file
    ///   - mddPath: Path to the MDD file (optional)
    ///   - fstPath: Path for FST index file
    ///   - readingsPath: Path for readings file
    ///   - recordPath: Path for record data file
    ///   - progressCallback: Progress callback for build process
    /// - Returns: Initialized MdictOptimized instance or nil on error
    static func createOptimizedWithProgress(fromBundle bundlePath: String,
                                           mddPath: String? = nil,
                                           fstPath: String,
                                           readingsPath: String,
                                           recordPath: String,
                                           progressCallback: BuildProgressCallback?) -> MdictOptimized? {
        do {
            // If FST already exists, load it directly
            if FileManager.default.fileExists(atPath: fstPath) {
                return try createMdictOptimizedFromFst(
                    fstPath: fstPath,
                    readingsPath: readingsPath,
                    recordPath: recordPath
                )
            } else {
                // Create from bundle with progress callback
                let bundle = try createMdictBundle(mdxPath: bundlePath, mddPath: mddPath ?? "")
                let optimized = try createMdictOptimizedFromBundleWithProgress(
                    bundle: bundle,
                    fstPath: fstPath,
                    readingsPath: readingsPath,
                    recordPath: recordPath,
                    progressCallback: progressCallback
                )
                
                // Cache the optimized instance
                let key = "\(bundlePath)_\(mddPath ?? "")"
                optimizedDictionaries[key] = optimized
                
                return optimized
            }
        } catch {
            print("Error creating MdictOptimized with progress: \(error)")
            return nil
        }
    }
    
    /// Get an already created MdictOptimized instance from cache
    /// - Parameter key: Cache key for the dictionary
    /// - Returns: MdictOptimized instance or nil if not found
    static func getOptimized(forKey key: String) -> MdictOptimized? {
        return optimizedDictionaries[key]
    }
    
    /// Remove a cached MdictOptimized instance
    /// - Parameter key: Cache key to remove
    static func removeCached(forKey key: String) {
        optimizedDictionaries.removeValue(forKey: key)
    }
}
